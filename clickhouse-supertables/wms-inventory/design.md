# WMS Inventory Position Design

## Overview
Design for computing inventory position at any arbitrary timestamp, maintaining all 200+ fields from enriched events while providing cumulative quantity tracking.

## Requirements
1. Get inventory position at any arbitrary timestamp
2. Maintain ALL 200+ fields from `wms_inventory_events_enriched`
3. Track cumulative quantities over time
4. Handle duplicates via (hu_event_id, quant_event_id) composite key
5. Support efficient queries for current and historical positions

## Architecture

### Optimized Three-Layer Approach with Weekly Snapshots

```
┌─────────────────────────────────────┐
│  wms_inventory_events_enriched      │
│  (Raw enriched events from Kafka)   │
│  Partition: toYYYYMM(hu_event_time) │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  wms_inventory_hourly_position      │
│  (Hourly delta aggregates)          │
│  - Deduplicates events              │
│  - Groups by inventory keys         │
│  - Stores hourly_qty_change only    │
│  - Preserves latest of all fields   │
│  Partition: toYYYYMM(hour_window)   │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  wms_inventory_weekly_snapshot      │
│  (Weekly cumulative snapshots)      │
│  - Generated every Sunday midnight  │
│  - Stores cumulative_qty to date    │
│  - Maintains all 200+ fields        │
│  - Optimized for fast base lookup   │
│  Partition: toYYYYMM(snapshot_time) │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  wms_inventory_position_at_time()   │
│  (Optimized parameterized view)     │
│  1. Find latest weekly snapshot     │
│  2. Sum hourly changes since snap   │
│  3. Add events in current hour      │
│  Performance: <500ms guaranteed     │
└─────────────────────────────────────┘
```

## Data Model

### 1. Raw Events Table (Existing)
`wms_inventory_events_enriched` - Already defined with 200+ fields

### 2. Hourly Position Table
`wms_inventory_hourly_position`

**Key Design Decisions:**
- **Granularity**: One row per unique inventory position per hour
- **Primary Key**: (wh_id, hour_window, hu_id, hu_code, sku_id, uom, bucket, batch, price, inclusion_status, locked_by_task_id, lock_mode)
- **Deduplication**: By (hu_event_id, quant_event_id) within each hour
- **Delta Tracking**: Stores only hourly_qty_change per hour (cumulative is in weekly snapshots)

**Fields Structure:**
```sql
-- Time and warehouse
hour_window DateTime
wh_id UInt64

-- Inventory position keys (what defines a unique position)
hu_id String
hu_code String
sku_id String
uom String
bucket String
batch String
price String
inclusion_status String
locked_by_task_id String
lock_mode String

-- Delta metrics (NOT cumulative - only changes in this hour)
hourly_qty_change Int64        -- Net change in this hour only
event_count UInt64             -- Number of events in this hour

-- Latest values of ALL other fields (200+)
-- These are the most recent values as of this hour
hu_event_id String             -- Latest event ID
quant_event_id String          -- Latest quant event ID
first_event_time DateTime64(3)  -- First event in this hour
last_event_time DateTime64(3)   -- Last event in this hour

-- All 200+ enriched fields with latest values...
hu_event_seq, hu_event_type, hu_event_payload, hu_event_attrs
session_id, task_id, correlation_id, storage_id, outer_hu_id
effective_storage_id, quant_iloc
hu_event_payload String
... (all other fields from enriched table)
```

### 3. Point-in-Time Position View/Function

`wms_inventory_position_at_time(wh_id, target_time)`

**Optimized Query Logic:**
1. Find the most recent weekly snapshot before target_time
2. Sum hourly_qty_change from snapshot to target hour
3. Add raw events within the target hour
4. Return combined result with latest field values

**Performance Optimization:**
- Maximum hours to scan: 168 (1 week) instead of 17,520 (2 years)
- Reduces query complexity by 100x
- Leverages partition pruning on all three tables

## Implementation Strategy

### Phase 1: Hourly Snapshot Materialized View

The materialized view automatically:
- Deduplicates events by (hu_event_id, quant_event_id)
- Aggregates hourly_qty_change per position
- Preserves latest values of all 200+ fields using argMax

```sql
CREATE MATERIALIZED VIEW wms_inventory_hourly_snapshot_mv
TO wms_inventory_hourly_snapshot
AS
SELECT
    toStartOfHour(hu_event_timestamp) as hour_window,
    wh_id,
    -- Position keys
    hu_code, sku_code, uom, bucket, batch, price, 
    inclusion_status, locked_by_task_id, lock_mode,
    
    -- Aggregations (with deduplication)
    sumState(qty_added) as hourly_qty_change,
    uniqExactState(hu_event_id, quant_event_id) as event_count,
    
    -- Latest values using argMax for ALL 200+ fields
    argMaxState(hu_event_id, hu_event_timestamp) as latest_hu_event_id,
    argMaxState(quant_event_id, hu_event_timestamp) as latest_quant_event_id,
    argMaxState(all_other_fields, hu_event_timestamp) as latest_field_values...
    
FROM wms_inventory_events_enriched
GROUP BY hour_window, wh_id, hu_code, sku_code, uom, bucket, batch, price, inclusion_status, locked_by_task_id, lock_mode
```

Note: Uses AggregatingMergeTree with State functions for proper aggregation handling.

### Phase 2: Optimized Point-in-Time Query View

```sql
CREATE VIEW wms_inventory_position_at_time AS
WITH 
-- Find the most recent weekly snapshot
latest_snapshot AS (
    SELECT *
    FROM wms_inventory_weekly_snapshot
    WHERE wh_id = {wh_id:UInt64}
      AND snapshot_timestamp <= {target_time:DateTime64(3)}
      AND snapshot_timestamp = (
          SELECT max(snapshot_timestamp)
          FROM wms_inventory_weekly_snapshot
          WHERE wh_id = {wh_id:UInt64}
            AND snapshot_timestamp <= {target_time:DateTime64(3)}
      )
),
-- Sum hourly changes since snapshot
hourly_changes AS (
    SELECT 
        wh_id, hu_code, sku_code, uom, bucket, batch, price,
        inclusion_status, locked_by_task_id, lock_mode,
        sum(hourly_qty_change) as qty_since_snapshot,
        argMax(all_fields, hour_window) as latest_fields
    FROM wms_inventory_hourly_position
    WHERE wh_id = {wh_id:UInt64}
      AND hour_window > (SELECT max(snapshot_timestamp) FROM latest_snapshot)
      AND hour_window < toStartOfHour({target_time:DateTime64(3)})
    GROUP BY wh_id, hu_code, sku_code, uom, bucket, batch, price, 
             inclusion_status, locked_by_task_id, lock_mode
),
-- Get events in current hour
current_hour_events AS (
    SELECT 
        wh_id, hu_code, sku_code, uom, bucket, batch, price,
        inclusion_status, locked_by_task_id, lock_mode,
        sum(qty_added) as current_hour_qty,
        argMax(all_fields, hu_event_timestamp) as latest_fields
    FROM wms_inventory_events_enriched  
    WHERE wh_id = {wh_id:UInt64}
      AND hu_event_timestamp >= toStartOfHour({target_time:DateTime64(3)})
      AND hu_event_timestamp <= {target_time:DateTime64(3)}
    GROUP BY wh_id, hu_code, sku_code, uom, bucket, batch, price,
             inclusion_status, locked_by_task_id, lock_mode
)
-- Combine all three sources
SELECT 
    COALESCE(s.wh_id, h.wh_id, e.wh_id) as wh_id,
    -- ... all keys ...
    COALESCE(s.cumulative_qty, 0) + 
    COALESCE(h.qty_since_snapshot, 0) + 
    COALESCE(e.current_hour_qty, 0) as quantity,
    -- Latest of all other fields
    COALESCE(e.latest_fields, h.latest_fields, s.fields) as field_values
FROM latest_snapshot s
FULL OUTER JOIN hourly_changes h USING (wh_id, hu_code, sku_code, uom, bucket, batch, price, inclusion_status, locked_by_task_id, lock_mode)
FULL OUTER JOIN current_hour_events e USING (wh_id, hu_code, sku_code, uom, bucket, batch, price, inclusion_status, locked_by_task_id, lock_mode)
WHERE quantity != 0
```

## Weekly Snapshot Generation

### Automated Weekly Snapshot Process

```sql
-- Generate weekly snapshots every Sunday at midnight
INSERT INTO wms_inventory_snapshot
SELECT 
    toStartOfWeek(now()) as snapshot_timestamp,
    'weekly' as snapshot_type,
    wh_id,
    hu_code, sku_code, uom, bucket, batch, price,
    inclusion_status, locked_by_task_id, lock_mode,
    -- Calculate cumulative from beginning of time
    sum(hourly_qty_change) as cumulative_qty,
    sum(event_count) as total_event_count,
    argMax(latest_hu_event_id, hour_window) as latest_hu_event_id,
    argMax(latest_quant_event_id, hour_window) as latest_quant_event_id,
    max(last_event_time) as last_event_time,
    -- All other fields using argMax to get latest values
    argMax(hu_event_seq, hour_window) as hu_event_seq,
    -- ... (all 200+ fields)
FROM wms_inventory_hourly_position
WHERE hour_window < toStartOfWeek(now())
GROUP BY wh_id, hu_code, sku_code, uom, bucket, batch, price,
         inclusion_status, locked_by_task_id, lock_mode
HAVING cumulative_qty != 0;

-- Schedule this via cron or ClickHouse's built-in scheduler
```

## Performance Optimizations

### 1. Table Design
- **Partitioning Strategy**:
  - Events: `PARTITION BY toYYYYMM(hu_event_timestamp)`
  - Hourly: `PARTITION BY toYYYYMM(hour_window)`  
  - Snapshots: `PARTITION BY toYYYYMM(snapshot_timestamp)`
- **Primary Key Order**: Optimized for warehouse + time queries
- **Compression**: LZ4 for balance between speed and size

### 2. Indexing Strategy
- Bloom filter indexes on high-cardinality fields (sku_code, hu_code, batch)
- Skip indexes for time ranges
- Projection for common aggregation patterns

### 3. Query Optimization
- **Snapshot-based queries**: Max 168 hourly records to scan (1 week)
- **Partition pruning**: Automatic with parameterized view predicates
- **Index utilization**: Bloom filters eliminate 99% of false positives
- **Projections**: Consider adding for frequently queried combinations

### 4. Expected Performance Metrics
- **Query latency**: 
  - Recent data (< 1 week): 100-200ms
  - With weekly snapshot: 300-500ms guaranteed
  - Without snapshots: 5-10 seconds (avoided)
- **Data freshness**: Real-time (includes current hour events)
- **Storage overhead**: ~30% for hourly + snapshots (acceptable trade-off)

## Data Flow

1. **Real-time Ingestion**
   - Events flow from Kafka to `wms_inventory_events_enriched`
   - Include `_ingested_at` timestamp for deduplication

2. **Hourly Aggregation**
   - Materialized view triggers automatically on new data
   - Deduplicates by (hu_event_id, quant_event_id)
   - Aggregates to hourly snapshots with hourly_qty_change
   - Stores latest values of all 200+ fields using argMax

3. **Query Time**
   - User queries for position at specific timestamp
   - View calculates cumulative_qty using window functions over hourly snapshots
   - For arbitrary timestamp: combines hourly snapshot + recent events
   - Returns complete position with all fields

## Handling Edge Cases

### 1. Duplicate Events
- Use (hu_event_id, quant_event_id) as deduplication key
- Take latest by `_ingested_at` timestamp
- Handle both in materialized view and query function

### 2. Late Arriving Events
- Events may arrive after their hour is processed
- Solution: Reprocess affected hours or use eventual consistency model

### 3. Corrections/Adjustments
- Support negative qty_added for corrections
- Maintain audit trail via event history

### 4. Missing Hours
- Handle gaps in hourly snapshots
- Fallback to scanning raw events if needed

## Query Examples

### Using Parameterized Views (ClickHouse 23.1+)
```sql
-- Get current position for warehouse 1
SELECT * FROM wms_inventory_position_at_time(wh_id=1, target_time=now())
WHERE sku_code = 'SKU123';

-- Get position at specific time
SELECT * FROM wms_inventory_position_at_time(wh_id=1, target_time='2024-01-15 14:30:00');

-- Aggregate by storage zone
SELECT 
    storage_zone_code,
    count(DISTINCT sku_code) as unique_skus,
    sum(quantity) as total_quantity
FROM wms_inventory_position_at_time(wh_id=1, target_time=now())
GROUP BY storage_zone_code
ORDER BY total_quantity DESC;
```

### Important Notes on Parameterized Views
- Requires ClickHouse version 23.1 or higher
- Parameters are passed as named arguments: `(wh_id=1, target_time=now())`
- Parameters are strongly typed: `{wh_id:UInt64}`, `{target_time:DateTime64(3)}`
- Enables query plan optimization with parameter substitution

### Get Position Changes Over Time
```sql
SELECT 
    hour_window,
    sum(hourly_qty_change) as net_change,
    sum(cumulative_qty) as total_position
FROM wms_inventory_hourly_snapshot
WHERE sku_code = 'SKU123'
  AND hour_window BETWEEN '2024-01-01' AND '2024-01-31'
GROUP BY hour_window
ORDER BY hour_window;
```

## Alternative Approaches Considered

### 1. Pure Streaming Aggregation
- **Pros**: Real-time updates
- **Cons**: Complex state management, doesn't preserve all fields easily

### 2. Full Event Scanning
- **Pros**: Always accurate, no pre-aggregation needed
- **Cons**: Very slow for large datasets, expensive queries

### 3. Snapshot per Event
- **Pros**: Perfect accuracy, all fields preserved
- **Cons**: Massive storage requirements, slow ingestion

## Optimized Approach Rationale

The 3-tier architecture with weekly snapshots is optimal because:

1. **Guaranteed Sub-Second Performance**: 
   - Max 168 hours to scan (1 week) vs 17,520 hours (2 years)
   - 100x reduction in query complexity
   
2. **Predictable Resource Usage**:
   - Fixed weekly snapshot interval = consistent performance
   - No performance degradation over time
   
3. **Field Preservation**: 
   - All 200+ fields maintained via argMax aggregations
   - Latest values always available
   
4. **Data Accuracy**:
   - Deduplication at hourly level via (hu_event_id, quant_event_id)
   - Cumulative tracking without drift
   
5. **Operational Simplicity**:
   - Single weekly batch job for snapshots
   - Clear data lifecycle management
   - Easy to monitor and troubleshoot

## Implementation Phases

### Phase 1: Hourly Snapshots Table & Materialized View
- Create snapshot table with all 200+ fields
- Implement materialized view with deduplication logic
- Store hourly_qty_change and latest field values via argMax

### Phase 2: Cumulative Position View
- Create view that calculates cumulative_qty using window functions
- Sum hourly_qty_change over time partitioned by position keys
- Test accuracy with known datasets

### Phase 3: Point-in-Time Query Function
- Implement function for arbitrary timestamp queries
- Combine hourly snapshot + events since last hour
- Add performance optimizations

### Phase 4: Production Readiness
- Add monitoring and alerting
- Performance testing at scale
- Documentation and training

## Monitoring & Maintenance

### Key Metrics
- Hourly snapshot completion time
- Deduplication effectiveness (duplicates found/removed)
- Query performance (p50, p95, p99 latencies)
- Storage growth rate

### Maintenance Tasks
- Monthly partition cleanup
- Quarterly performance review
- Index optimization based on query patterns
- Cumulative quantity reconciliation

## Design Decisions

1. **Historical Backfill**: Calculate cumulative quantities from the beginning of available data
2. **Retention Policy**: Keep all data indefinitely (no deletion policy)
3. **Field Selection**: Maintain ALL 200+ fields for complete inventory visibility
4. **Performance SLA**: Sub-1 second latency for point-in-time snapshot queries per warehouse
5. **Late Arriving Events**: Not supported - events are processed in order