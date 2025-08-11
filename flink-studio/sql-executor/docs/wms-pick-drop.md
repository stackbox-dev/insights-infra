# WMS Pick Drop Pipeline Documentation

## Overview
The WMS Pick Drop pipeline is a three-tier streaming data processing system that tracks and enriches warehouse pick-and-drop operations. The pipeline uses Apache Flink to process CDC (Change Data Capture) events from PostgreSQL via Debezium and produces enriched analytics data.

## Architecture

### Three-Tier Pipeline Structure

```
┌─────────────────────────┐
│   Source CDC Tables     │
│  - pd_pick_item        │
│  - pd_drop_item        │
│  - pd_pick_drop_mapping│
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│    Basic Pipeline       │
│  wms-pick-drop-basic    │
│  (12-hour TTL joins)    │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  pick_drop_basic topic  │
└──────┬──────────┬───────┘
       │          │
       ▼          ▼
┌──────────┐ ┌───────────┐
│Historical│ │ Real-time │
│Enrichment│ │Enrichment │
└──────────┘ └───────────┘
```

## Pipeline Components

### 1. Basic Pipeline (`wms-pick-drop-basic.sql`)

**Purpose**: Joins core CDC tables to create comprehensive pick-drop event data.

**Key Features**:
- Joins three source tables: `pd_pick_item`, `pd_drop_item`, and `pd_pick_drop_mapping`
- Uses **TTL-based regular joins** (12-hour TTL) instead of interval joins
- Handles Debezium's random event ordering (events ordered by primary key, not time)
- Properly propagates `is_snapshot` and `event_time` fields for downstream processing
- Filters tombstones using `WHERE event_time > TIMESTAMP '1970-01-01 00:00:00'`

**Technical Configuration**:
```sql
-- State TTL to prevent unbounded growth
SET 'table.exec.state.ttl' = '43200000'; -- 12 hours in milliseconds

-- Regular joins without time constraints
LEFT JOIN pick_drop_mapping pdm 
    ON pi.id = pdm.pickItemId
    AND pi.whId = pdm.whId
```

**Output**: 
- Topic: `sbx_uat.wms.internal.pick_drop_basic`
- Format: Upsert-Kafka with Avro
- Primary Key: `(pick_item_id, drop_item_id)`

### 2. Historical Enrichment Pipeline (`wms-pick-drop-enriched-historical.sql`)

**Purpose**: Enriches basic pick-drop data with dimension tables for batch/historical processing.

**Key Features**:
- Consumes from `pick_drop_basic` topic
- Uses **temporal joins** (`FOR SYSTEM_TIME AS OF`) for point-in-time correct enrichment
- Enriches with:
  - Sessions and Tasks
  - Workers
  - SKUs (both picked and dropped, with override logic)
  - Handling Units
  - Trips (child and parent trips via trip relations)
- Optimized for processing large historical datasets and snapshots
- Higher latency tolerance for batch processing

**Enrichment Pattern**:
```sql
LEFT JOIN sessions FOR SYSTEM_TIME AS OF pb.pick_item_updated_at AS s
    ON pb.session_id = s.id AND pb.wh_id = s.whId
```

### 3. Real-time Enrichment Pipeline (`wms-pick-drop-enriched-realtime.sql`)

**Purpose**: Same enrichment as historical but optimized for real-time streaming.

**Key Features**:
- Consumes from `pick_drop_basic` topic
- Identical enrichment logic as historical pipeline
- Lower latency configuration for live data
- Optimized checkpointing and mini-batch settings for real-time processing
- Same temporal join pattern for consistency

## Data Model

### Source Tables (CDC from PostgreSQL)

#### pd_pick_item
- **Fields**: 107 columns including pick location, SKU, quantities, timestamps, worker info
- **Key Fields**: `id`, `whId`, `sessionId`, `taskId`, `skuId`, `pickedAt`, `pickedBy`
- **CDC Fields**: `__source_snapshot` for snapshot detection

#### pd_drop_item
- **Fields**: 78 columns including drop location, quantities, timestamps
- **Key Fields**: `id`, `whId`, `sessionId`, `taskId`, `droppedAt`, `droppedBy`
- **CDC Fields**: `__source_snapshot` for snapshot detection

#### pd_pick_drop_mapping
- **Fields**: Links pick items to drop items
- **Key Fields**: `id`, `pickItemId`, `dropItemId`, `whId`
- **CDC Fields**: `__source_snapshot` for snapshot detection

### Intermediate Table

#### pick_drop_basic
- **Total Fields**: 146 columns
- **Primary Key**: `(pick_item_id, drop_item_id)`
- **Special Fields**:
  - `is_snapshot`: Combined snapshot flag (AND logic across sources)
  - `event_time`: Maximum event time across all sources
  - `deactivated_at`: Coalesced from drop and pick deactivation
- **Purpose**: Denormalized view of pick-drop operations

### Final Enriched Table

#### pick_drop_summary
- **Total Fields**: 332 columns
- **Categories**:
  - Core identifiers (4 fields)
  - Pick item details (45+ fields)
  - Drop item details (40+ fields)
  - Task enrichment (17 fields)
  - Session enrichment (9 fields)
  - Trip enrichment (20+ fields)
  - Worker enrichment (5 fields)
  - SKU enrichment for both picked and dropped (124 fields total)
  - System and technical fields (60+ fields)

## Key Technical Decisions

### 1. TTL vs Interval Joins

**Problem**: Debezium CDC events arrive with random ordering based on primary keys, not timestamps. This breaks watermark progression in interval joins.

**Solution**: Use TTL-based regular joins
- State is cleaned up based on access time, not watermarks
- Handles random event ordering correctly
- Better for processing historical snapshots
- Simpler logic without complex time windows

### 2. Snapshot Detection Strategy

**Pattern**: Forward-only metadata
- `is_snapshot` field is computed from `__source_snapshot` 
- Combined using AND logic: `pi.is_snapshot AND pdm.is_snapshot AND di.is_snapshot`
- Never used for filtering or business logic
- Only forwarded to sink for downstream consumers

### 3. Temporal Joins for Enrichment

**Benefits**:
- Point-in-time correct enrichment
- Automatic versioned state management
- More efficient than interval joins for dimensions
- Perfect for slowly changing dimensions

### 4. Event Time Management

**Strategy**:
- Use business timestamps (`updated_at`, `created_at`), not `__source_ts_ms`
- Compute `event_time` using COALESCE for null handling
- Use GREATEST when combining multiple event times
- Filter tombstones with `event_time > '1970-01-01'`

## Performance Optimization

### State Management
- 12-hour TTL for basic pipeline joins
- Temporal joins manage their own versioned state
- RocksDB with LZ4 compression for state backend

### Processing Configuration
```sql
-- Mini-batch for throughput
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '1s';
SET 'table.exec.mini-batch.size' = '5000';

-- Checkpointing for fault tolerance
SET 'execution.checkpointing.interval' = '600000'; -- 10 minutes
SET 'execution.checkpointing.timeout' = '1800000'; -- 30 minutes

-- Parallelism
SET 'parallelism.default' = '2';
```

### Join Optimization
- Hash join hints: `/*+ USE_HASH_JOIN */`
- Join reordering enabled
- Multiple input optimization

## Deployment

### Environment Configuration
```bash
export KAFKA_USERNAME="your-username"
export KAFKA_PASSWORD="your-password"
export TRUSTSTORE_PASSWORD="truststore-password"
```

### Execution Commands
```bash
# Run basic pipeline
python flink_sql_executor.py --sql-file sbx-uat/wms-pick-drop-basic.sql

# Run historical enrichment
python flink_sql_executor.py --sql-file sbx-uat/wms-pick-drop-enriched-historical.sql

# Run real-time enrichment
python flink_sql_executor.py --sql-file sbx-uat/wms-pick-drop-enriched-realtime.sql
```

### Monitoring
- Check Flink UI for job status and backpressure
- Monitor checkpoint duration and state size
- Verify output in Kafka topics
- Track consumer lag for real-time processing

## Data Quality Considerations

### Null Handling
- Extensive use of COALESCE for nullable fields
- Default values for all enrichment fields
- `table.exec.sink.not-null-enforcer = 'drop'` for sink resilience

### Deduplication
- Upsert-Kafka ensures exactly-once semantics
- Primary key `(pick_item_id, drop_item_id)` prevents duplicates

### Data Completeness
- LEFT JOINs preserve all pick items even without drops
- Enrichment fields default to empty/zero when dimension data missing
- Temporal joins ensure consistent point-in-time view

## Use Cases

### Analytics Queries
1. **Worker Performance**: Analyze pick/drop rates by worker
2. **SKU Movement**: Track product flow through warehouse
3. **Task Efficiency**: Measure task completion times
4. **Trip Planning**: Optimize trip loading and routing
5. **Inventory Velocity**: Calculate SKU turnover rates

### Operational Monitoring
1. Real-time pick/drop activity dashboards
2. Worker productivity tracking
3. Task queue monitoring
4. Exception and error detection

## Future Considerations

### Potential Enhancements
1. Add aggregation pipelines for hourly/daily summaries
2. Implement anomaly detection for unusual patterns
3. Add data quality scoring
4. Create specialized views for specific use cases

### Scalability
- Increase parallelism for higher throughput
- Adjust TTL based on join patterns
- Consider partitioned sinks for very high volume
- Implement tiered storage for historical data