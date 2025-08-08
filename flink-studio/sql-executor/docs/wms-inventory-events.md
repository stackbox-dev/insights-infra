# WMS Inventory Events Pipeline Documentation

## Overview

The WMS Inventory Events pipeline processes warehouse inventory movements by joining handling unit events with their associated quantity events, then enriching the data with dimensional information from multiple master data sources. The pipeline is split into three stages:

1. **Basic Pipeline**: Joins handling unit events with quantity events
2. **Historical Enrichment**: Batch processing of all historical data with full enrichment
3. **Real-time Enrichment**: Continuous streaming of new events with full enrichment

## Architecture

```
┌─────────────────────────┐     ┌─────────────────────────┐
│  handling_unit_event    │     │ handling_unit_quant_evt │
└───────────┬─────────────┘     └───────────┬─────────────┘
            │                                │
            └──────────┬─────────────────────┘
                       │
                       ▼
            ┌──────────────────────┐
            │ inventory_events_basic│
            └──────────┬───────────┘
                       │
        ┌──────────────┴──────────────┐
        │                              │
        ▼                              ▼
┌───────────────────┐     ┌────────────────────┐
│Historical Pipeline│     │Real-time Pipeline  │
├───────────────────┤     ├────────────────────┤
│ • Batch mode      │     │ • Streaming mode   │
│ • All past data   │     │ • New events only  │
│ • View-based joins│     │ • Temporal joins   │
└───────────┬───────┘     └─────────┬──────────┘
            │                        │
            └───────────┬────────────┘
                        ▼
         ┌──────────────────────────┐
         │inventory_events_enriched │
         └──────────────────────────┘
```

## Pipeline Files

### 1. Basic Pipeline
**File**: `sbx-uat/wms-inventory-events-basic.sql`

**Purpose**: Joins handling unit events with quantity events within a 5-minute window.

**Key Features**:
- Interval join with 5-minute window to correlate events
- State TTL configuration to prevent unbounded state growth
- Composite primary key (hu_event_id, quant_event_id)
- Handles missing timestamps in quant_events

**Source Tables**:
- `sbx_uat.wms.public.handling_unit_event` - Warehouse handling unit movements
- `sbx_uat.wms.public.handling_unit_quant_event` - Quantity changes associated with HU events

**Output**: `sbx_uat.wms.internal.inventory_events_basic`

### 2. Historical Enrichment Pipeline
**File**: `sbx-uat/wms-inventory-enriched-historical.sql`

**Purpose**: Processes all historical inventory events with full dimensional enrichment.

**Key Features**:
- BATCH execution mode for bounded processing
- Creates views with ROW_NUMBER() to get latest dimension records
- Regular LEFT JOINs (not temporal) for deterministic results
- Direct join with storage_bin_master using bin_id
- Processes from earliest to latest offset then terminates

**Enrichment Sources**:
- `handling_units` - Handling unit master data
- `handling_unit_kinds` - HU type definitions
- `storage_bin_master` - Storage location master data
- `skus_master` - Product/SKU master data

### 3. Real-time Enrichment Pipeline
**File**: `sbx-uat/wms-inventory-enriched-realtime.sql`

**Purpose**: Continuously processes new inventory events with full enrichment.

**Key Features**:
- STREAMING execution mode for unbounded processing
- Temporal joins using event time for point-in-time accuracy
- Two-step join for storage bins (bin → bin_master via bin_code)
- Watermark alignment for synchronized source processing
- Starts from latest offset (after historical completes)

**Special Handling**:
- Uses `storage_bin` intermediate table to resolve bin_code
- All dimension tables use upsert-kafka with proper primary keys
- 5-second watermark delay for dimension table synchronization

## Data Model

### Core Event Fields

#### From handling_unit_event:
- `hu_event_id` - Unique event identifier
- `wh_id` - Warehouse identifier
- `hu_id` - Handling unit identifier
- `hu_event_type` - Type of event (MOVE, CREATE, etc.)
- `hu_event_timestamp` - Event occurrence time
- `storage_id` - Current storage location
- `outer_hu_id` - Parent handling unit
- `effective_storage_id` - Effective storage after movement

#### From handling_unit_quant_event:
- `quant_event_id` - Unique quantity event identifier
- `sku_id` - Product/SKU identifier
- `uom` - Unit of measure
- `batch` - Batch/lot number
- `qty_added` - Quantity change
- `inclusion_status` - Inventory status

### Enriched Fields

#### Handling Unit Enrichment:
- `hu_code` - Human-readable HU code
- `hu_state` - Current state (ACTIVE, CLOSED, etc.)
- `hu_kind_*` - HU type information (15+ fields)

#### Storage Enrichment:
- `storage_*` - Current storage location details (50+ fields)
- `effective_storage_*` - Target storage location details (50+ fields)
- Includes zone, area, bin type, capacity, and position information

#### Outer HU Enrichment:
- `outer_hu_*` - Parent HU details (25+ fields)
- Includes parent HU type and characteristics

#### SKU Enrichment:
- `sku_*` - Product master data (35+ fields)
- Includes category, brand, dimensions, and packaging information

## Execution Workflow

### Step 1: Deploy Basic Pipeline
```bash
python flink_sql_executor.py --sql-file sbx-uat/wms-inventory-events-basic.sql
```
This creates the foundational joined events stream.

### Step 2: Run Historical Enrichment
```bash
python flink_sql_executor.py --sql-file sbx-uat/wms-inventory-enriched-historical.sql
```
**Monitor completion**:
```bash
kubectl exec -n flink-studio flink-sql-gateway-0 -- \
  kafka-consumer-groups \
  --bootstrap-server sbx-stag-kafka-stackbox.e.aivencloud.com:22167 \
  --group sbx-uat-wms-inventory-enriched \
  --describe
```

### Step 3: Start Real-time Enrichment
```bash
python flink_sql_executor.py --sql-file sbx-uat/wms-inventory-enriched-realtime.sql
```
Start only after historical pipeline completes to avoid duplicate processing.

## Key Design Decisions

### 1. Interval Join for Event Correlation
The basic pipeline uses a 5-minute interval join because:
- Quant events may lack timestamps but are created with HU events
- 5-minute window captures related events while limiting state
- TTL configuration prevents unbounded state growth

### 2. Storage Bin Resolution
- **Historical**: Direct join with storage_bin_master using bin_id
- **Real-time**: Two-step join via storage_bin to get bin_code
- Required because storage_bin_master primary key is (wh_id, bin_code)

### 3. Comprehensive Enrichment
The pipeline includes ALL fields from dimension tables:
- Provides complete context for downstream analytics
- Eliminates need for additional lookups
- Supports various use cases without schema changes

### 4. View-based Latest Records (Historical)
```sql
CREATE VIEW handling_units_latest AS
SELECT * FROM (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY `whId`, id ORDER BY event_time DESC) as rn
    FROM handling_units
) WHERE rn = 1;
```
Ensures deterministic results by selecting the latest version of each record.

## Performance Considerations

### State Management
- 5-minute TTL on join state prevents memory issues
- Watermark alignment ensures coordinated progress
- RocksDB with incremental checkpoints for large state

### Parallelism
- Default parallelism: 4 (adjustable based on volume)
- Sink parallelism matches default for balanced processing
- Mini-batch optimization for throughput

### Memory Configuration
```sql
SET 'taskmanager.memory.managed.fraction' = '0.8';
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.size' = '5000';
```

## Monitoring and Troubleshooting

### Check Pipeline Status
```bash
# Get job status
kubectl exec -n flink-studio flink-session-cluster-taskmanager-1-1 -- \
  curl -s http://flink-session-cluster-rest:8081/jobs | jq

# Check for enrichment gaps
kubectl exec -n flink-studio flink-sql-gateway-0 -- \
  kafka-console-consumer \
  --bootstrap-server sbx-stag-kafka-stackbox.e.aivencloud.com:22167 \
  --topic sbx_uat.wms.internal.inventory_events_enriched \
  --from-beginning --max-messages 10
```

### Common Issues

#### 1. Missing Enrichment Data
- **Symptom**: NULL values in enriched fields
- **Cause**: Dimension data not available at event time
- **Solution**: Check dimension table lag and watermark settings

#### 2. High Memory Usage
- **Symptom**: TaskManager OOM errors
- **Cause**: Large state accumulation in joins
- **Solution**: Verify TTL settings, reduce mini-batch size

#### 3. Slow Processing
- **Symptom**: Growing consumer lag
- **Cause**: Complex joins with large dimension tables
- **Solution**: Increase parallelism, optimize join order

## Data Quality Checks

### Validate Basic Pipeline
```sql
-- Check event correlation rate
SELECT 
    COUNT(*) as total_events,
    COUNT(DISTINCT hu_event_id) as unique_hu_events,
    COUNT(DISTINCT quant_event_id) as unique_quant_events
FROM inventory_events_basic;
```

### Validate Enrichment
```sql
-- Check enrichment completeness
SELECT 
    COUNT(*) as total,
    SUM(CASE WHEN hu_code = '' THEN 1 ELSE 0 END) as missing_hu,
    SUM(CASE WHEN storage_bin_code = '' THEN 1 ELSE 0 END) as missing_storage,
    SUM(CASE WHEN sku_code = '' THEN 1 ELSE 0 END) as missing_sku
FROM inventory_events_enriched;
```

## Future Enhancements

1. **Additional Enrichments**
   - Worker information from session/task joins
   - Location hierarchy rollups
   - Real-time inventory position calculation

2. **Performance Optimizations**
   - Broadcast joins for small dimension tables
   - Materialized views for frequently accessed combinations
   - Partition pruning for historical queries

3. **Data Quality**
   - Automated anomaly detection
   - Missing data alerts
   - Enrichment coverage metrics

## Related Documentation

- [WMS Pick-Drop Pipeline](./wms-pick-drop.md) - Similar enrichment pattern
- [Running Enrichment Pipelines](./running-enrichment-pipeline.md) - Operational guide
- [CLAUDE.md](../CLAUDE.md) - Coding standards and patterns