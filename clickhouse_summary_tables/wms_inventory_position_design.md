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

### Three-Layer Approach

```
┌─────────────────────────────────────┐
│  wms_inventory_events_enriched      │
│  (Raw enriched events from Kafka)   │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  wms_inventory_hourly_snapshot      │
│  (Hourly snapshots with all fields) │
│  - Deduplicates events              │
│  - Groups by inventory keys         │
│  - Maintains cumulative qty         │
│  - Preserves latest of all fields   │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  wms_inventory_position_at()        │
│  (Function/View for point-in-time)  │
│  - Takes timestamp parameter        │
│  - Uses hourly snapshot as base     │
│  - Adds events since last hour      │
└─────────────────────────────────────┘
```

## Data Model

### 1. Raw Events Table (Existing)
`wms_inventory_events_enriched` - Already defined with 200+ fields

### 2. Hourly Snapshot Table
`wms_inventory_hourly_snapshot`

**Key Design Decisions:**
- **Granularity**: One row per unique inventory position per hour
- **Primary Key**: (wh_id, hour_window, hu_code, sku_code, uom, bucket, batch, price, inclusion_status, locked_by_task_id, lock_mode)
- **Deduplication**: By (hu_event_id, quant_event_id) within each hour
- **Cumulative Tracking**: Running total of qty_added from beginning of time

**Fields Structure:**
```sql
-- Time and warehouse
hour_window DateTime
wh_id UInt64

-- Inventory position keys (what defines a unique position)
hu_code String
sku_code String  
uom String
bucket String
batch String
price String
inclusion_status String
locked_by_task_id String
lock_mode String

-- Cumulative metrics
cumulative_qty Int64           -- Running total from all time
hourly_qty_change Int32        -- Net change in this hour only
event_count UInt32             -- Number of events in this hour

-- Latest values of ALL other fields (200+)
-- These are the most recent values as of this hour
hu_event_id String             -- Latest event ID
quant_event_id String          -- Latest quant event ID
hu_event_timestamp DateTime64(3)  -- Latest event timestamp

-- All 200+ enriched fields with latest values...
hu_id String
hu_event_type String
hu_event_payload String
... (all other fields from enriched table)
```

### 3. Point-in-Time Position View/Function

`wms_inventory_position_at(timestamp)`

**Logic:**
1. Find the last hourly snapshot before the requested timestamp
2. Get cumulative_qty from that snapshot
3. Add any events between hour_window and requested timestamp
4. Return combined result with latest field values

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

### Phase 2: Point-in-Time Query View

```sql
CREATE FUNCTION wms_inventory_position_at(target_time DateTime64(3))
AS
WITH 
-- Get the base hourly snapshot
base_snapshot AS (
    SELECT *
    FROM wms_inventory_hourly_snapshot
    WHERE hour_window = toStartOfHour(target_time)
),
-- Get events after the hour boundary
incremental_events AS (
    SELECT 
        wh_id,
        hu_code, sku_code, uom, bucket, batch, price,
        inclusion_status, locked_by_task_id, lock_mode,
        sum(qty_added) as additional_qty,
        argMax(all_fields, hu_event_timestamp) as latest_fields
    FROM wms_inventory_events_enriched  
    WHERE hu_event_timestamp > toStartOfHour(target_time)
      AND hu_event_timestamp <= target_time
    GROUP BY wh_id, hu_code, sku_code, uom, bucket, batch, price, inclusion_status, locked_by_task_id, lock_mode
)
-- Combine base + incremental
SELECT 
    COALESCE(b.wh_id, i.wh_id) as wh_id,
    -- ... all keys ...
    COALESCE(b.cumulative_qty, 0) + COALESCE(i.additional_qty, 0) as cumulative_qty,
    -- Latest of all other fields
    COALESCE(i.latest_fields, b.fields) as field_values
FROM base_snapshot b
FULL OUTER JOIN incremental_events i USING (wh_id, hu_code, sku_code, uom, bucket, batch, price, inclusion_status, locked_by_task_id, lock_mode)
```

## Performance Optimizations

### 1. Table Design
- **Partitioning**: By `toYYYYMM(hour_window)` for efficient time-range queries
- **Primary Key Order**: Optimized for common query patterns
- **Compression**: LZ4 for balance between speed and size

### 2. Indexing Strategy
- Bloom filter indexes on high-cardinality fields (sku_code, hu_code, batch)
- Skip indexes for time ranges
- Projection for common aggregation patterns

### 3. Query Optimization
- Pre-calculate hourly snapshots to avoid scanning all events
- Use proper partition pruning in queries
- Leverage projections for common access patterns

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

### Get Current Position
```sql
SELECT * FROM wms_inventory_position_at(now())
WHERE sku_code = 'SKU123';
```

### Get Position at Specific Time
```sql
SELECT * FROM wms_inventory_position_at('2024-01-15 14:30:00')
WHERE wh_id = 1;
```

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

## Chosen Approach Rationale

The hourly snapshot + incremental events approach is chosen because:

1. **Balanced Performance**: Pre-aggregation reduces query cost while maintaining flexibility
2. **Field Preservation**: Can maintain all 200+ fields via argMax aggregations
3. **Accuracy**: Deduplication ensures correct quantities
4. **Scalability**: Hourly granularity manageable even at high volumes
5. **Query Flexibility**: Supports any timestamp queries, not just hourly boundaries

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

## Open Questions

1. **Historical Backfill**: How far back should we calculate cumulative quantities?
2. **Retention Policy**: How long to keep hourly snapshots vs raw events?
3. **Field Selection**: Should we really maintain ALL 200+ fields or identify subset?
4. **Performance SLA**: What's acceptable query latency for point-in-time positions?
5. **Late Arriving Events**: How to handle events that arrive after their hour has been processed?