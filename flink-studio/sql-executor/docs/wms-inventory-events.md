# WMS Inventory Events Pipeline Documentation

## Overview

The WMS Inventory Events pipeline is a three-tier streaming data processing system that tracks warehouse inventory movements through handling unit events. Unlike the pick-drop pipeline which processes CDC data, this pipeline processes event-driven data from warehouse operations. The pipeline uses Apache Flink to join and enrich event streams for real-time inventory analytics.

## Architecture

### Three-Tier Pipeline Structure

```
┌─────────────────────────┐     ┌─────────────────────────┐
│  handling_unit_event    │     │handling_unit_quant_event│
│  (Event stream with     │     │ (Quantity events without│
│   timestamps)           │     │  timestamps)            │
└───────────┬─────────────┘     └───────────┬─────────────┘
            │                                │
            └──────────┬─────────────────────┘
                       │
                       ▼
            ┌──────────────────────┐
            │  Basic Pipeline       │
            │inventory_events_basic │
            │ (1-hour TTL joins)    │
            └──────────┬───────────┘
                       │
                       ▼
            ┌──────────────────────┐
            │inventory_events_basic │
            │       topic           │
            └──────┬──────┬────────┘
                   │      │
                   ▼      ▼
          ┌──────────┐ ┌───────────┐
          │Historical│ │ Real-time │
          │Enrichment│ │Enrichment │
          └──────────┘ └───────────┘
```

## Pipeline Components

### 1. Basic Pipeline (`wms-inventory-events-basic.sql`)

**Purpose**: Joins handling unit events with their associated quantity events.

**Key Features**:
- Joins two event streams: `handling_unit_event` and `handling_unit_quant_event`
- Uses **TTL-based regular joins** (1-hour TTL) instead of interval joins
- Handles the fact that quant events lack timestamps
- No CDC fields (`is_snapshot`, `event_time`) as these are event streams, not CDC
- Uses native event timestamp from `handling_unit_event`

**Technical Configuration**:
```sql
-- State TTL to prevent unbounded state growth
SET 'table.exec.state.ttl' = '3600000'; -- 1 hour in milliseconds

-- Regular join on foreign key relationship
LEFT JOIN handling_unit_quant_events huqe 
    ON hue.id = huqe.huEventId
    AND hue.whId = huqe.whId
```

**Important Note**: These are **event-driven tables**, not CDC tables, so:
- No `__source_snapshot` field exists
- No `is_snapshot` computation needed
- No `event_time` computation (uses native `timestamp` field)
- Watermarks are defined directly on the event timestamp

**Output**: 
- Topic: `sbx_uat.wms.internal.inventory_events_basic`
- Format: Upsert-Kafka with Avro
- Primary Key: `(hu_event_id, quant_event_id)`

### 2. Historical Enrichment Pipeline (`wms-inventory-enriched-historical.sql`)

**Purpose**: Enriches basic inventory events with dimension tables for batch/historical processing.

**Key Features**:
- Consumes from `inventory_events_basic` topic
- Uses **temporal joins** for point-in-time correct enrichment
- Enriches with:
  - Handling units master data
  - Handling unit kinds (types)
  - Storage bins (current and effective locations)
  - SKU master data
- Optimized for processing large historical datasets
- Higher latency tolerance for batch processing

**Enrichment Pattern**:
```sql
LEFT JOIN handling_units FOR SYSTEM_TIME AS OF ieb.hu_event_timestamp AS hu
    ON ieb.hu_id = hu.id AND ieb.wh_id = hu.whId
```

### 3. Real-time Enrichment Pipeline (`wms-inventory-enriched-realtime.sql`)

**Purpose**: Same enrichment as historical but optimized for real-time streaming.

**Key Features**:
- Consumes from `inventory_events_basic` topic
- Identical enrichment logic as historical pipeline
- Lower latency configuration for live data
- Optimized checkpointing and mini-batch settings
- Uses temporal joins for dimension lookups

## Data Model

### Source Tables (Event Streams)

#### handling_unit_event
- **Nature**: Event stream with timestamps
- **Fields**: 14 columns including event metadata
- **Key Fields**: `id`, `whId`, `huId`, `type`, `timestamp`
- **Watermark**: On `timestamp` field (native event time)
- **No CDC fields**: This is an event table, not CDC

#### handling_unit_quant_event
- **Nature**: Event stream without timestamps
- **Fields**: 11 columns with quantity details
- **Key Fields**: `id`, `huEventId`, `skuId`, `qtyAdded`
- **No watermark**: Events lack timestamps
- **Correlation**: Links to handling_unit_event via `huEventId`

### Intermediate Table

#### inventory_events_basic
- **Total Fields**: 23 columns
- **Primary Key**: `(hu_event_id, quant_event_id)`
- **Watermark**: On `hu_event_timestamp` from the HU event
- **Purpose**: Correlated view of HU movements with quantities

### Final Enriched Table

#### inventory_events_enriched
- **Total Fields**: 200+ columns
- **Categories**:
  - Core event fields (23 from basic)
  - Handling unit enrichment (15+ fields)
  - HU kind enrichment (15+ fields)
  - Storage bin enrichment (50+ fields for current location)
  - Effective storage enrichment (50+ fields for target location)
  - Outer HU enrichment (25+ fields for parent HU)
  - SKU enrichment (35+ fields)

## Key Technical Decisions

### 1. TTL for Event Correlation

**Challenge**: Quant events arrive without timestamps but are logically related to HU events.

**Solution**: Use TTL-based regular joins
- 1-hour TTL allows sufficient time for related events to arrive
- State is cleaned up based on access time
- Works well with event streams that have natural ordering

### 2. No CDC Processing

**Key Difference from Pick-Drop Pipeline**:
- These are **event streams**, not CDC tables
- No snapshot detection needed
- No `is_snapshot` or computed `event_time` fields
- Uses native event timestamps directly

### 3. Temporal Joins for Enrichment

**Same as Pick-Drop**:
- Point-in-time correct enrichment using event timestamp
- Automatic versioned state management
- Efficient for slowly changing dimensions

### 4. Storage Bin Resolution

**Two-Step Process**:
1. Event has `storage_id` (bin ID)
2. Join to get `bin_code`
3. Join to `storage_bin_master` using `(wh_id, bin_code)`

This is necessary because storage_bin_master uses bin_code as part of its primary key.

## Performance Optimization

### State Management
- 1-hour TTL for basic pipeline joins
- Temporal joins manage their own versioned state
- RocksDB with LZ4 compression

### Processing Configuration
```sql
-- Mini-batch for throughput
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '1s';
SET 'table.exec.mini-batch.size' = '5000';

-- Checkpointing
SET 'execution.checkpointing.interval' = '600000'; -- 10 minutes
SET 'execution.checkpointing.timeout' = '1800000'; -- 30 minutes

-- Parallelism
SET 'parallelism.default' = '2';
```

### Join Optimization
- Hash join hints where applicable
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
python flink_sql_executor.py --sql-file sbx-uat/wms-inventory-events-basic.sql

# Run historical enrichment
python flink_sql_executor.py --sql-file sbx-uat/wms-inventory-enriched-historical.sql

# Run real-time enrichment
python flink_sql_executor.py --sql-file sbx-uat/wms-inventory-enriched-realtime.sql
```

### Monitoring
- Check Flink UI for job status
- Monitor checkpoint metrics
- Verify output in Kafka topics
- Track event correlation rates

## Data Quality Considerations

### Event Correlation
- Not all HU events have associated quant events
- LEFT JOIN preserves all HU events
- COALESCE provides defaults for missing quant data

### Null Handling
- Extensive COALESCE for nullable enrichment fields
- Default values prevent downstream issues
- `table.exec.sink.not-null-enforcer = 'drop'` for resilience

### Deduplication
- Upsert-Kafka with composite primary key
- Ensures exactly-once semantics
- Handles event replay scenarios

## Use Cases

### Real-time Analytics
1. **Inventory Movement Tracking**: Live view of stock movements
2. **Location Utilization**: Monitor bin and zone usage
3. **SKU Velocity**: Track product movement patterns
4. **Exception Detection**: Identify unusual inventory events

### Operational Monitoring
1. Real-time inventory position
2. Handling unit lifecycle tracking
3. Storage optimization analysis
4. Cross-docking efficiency

## Comparison with Pick-Drop Pipeline

| Aspect | Inventory Events | Pick-Drop |
|--------|-----------------|-----------|
| **Data Source** | Event streams | CDC (Debezium) |
| **Ordering** | Natural event order | Random (by PK) |
| **Timestamps** | Native event timestamps | Computed from business fields |
| **Snapshot Detection** | Not applicable | Required for CDC |
| **Primary Challenge** | Correlating events without timestamps | Handling random CDC ordering |
| **Join Strategy** | TTL-based regular joins | TTL-based regular joins |
| **Enrichment** | Temporal joins | Temporal joins |

## Future Considerations

### Potential Enhancements
1. Add aggregation for inventory snapshots
2. Implement real-time inventory position calculation
3. Add anomaly detection for unusual movements
4. Create specialized views for specific operations

### Scalability
- Increase parallelism for higher event rates
- Adjust TTL based on event correlation patterns
- Consider event buffering for burst handling
- Implement backpressure monitoring

## Troubleshooting Guide

### Common Issues

#### 1. Missing Quant Events
- **Symptom**: Empty quant fields in output
- **Cause**: Some HU events don't generate quant events
- **Solution**: This is normal; ensure COALESCE defaults are appropriate

#### 2. High State Size
- **Symptom**: Growing checkpoint size
- **Cause**: TTL too long or high event rate
- **Solution**: Reduce TTL or increase parallelism

#### 3. Enrichment Lag
- **Symptom**: Old dimension data in enriched output
- **Cause**: Dimension table update lag
- **Solution**: Check dimension table refresh rates

### Validation Queries

```sql
-- Check event correlation rate
SELECT 
    COUNT(DISTINCT hu_event_id) as hu_events,
    COUNT(DISTINCT quant_event_id) as quant_events,
    COUNT(*) as total_records
FROM inventory_events_basic;

-- Check enrichment completeness
SELECT 
    COUNT(*) as total,
    SUM(CASE WHEN hu_code = '' THEN 1 ELSE 0 END) as missing_hu,
    SUM(CASE WHEN storage_bin_code = '' THEN 1 ELSE 0 END) as missing_storage,
    SUM(CASE WHEN sku_code = '' THEN 1 ELSE 0 END) as missing_sku
FROM inventory_events_enriched;
```