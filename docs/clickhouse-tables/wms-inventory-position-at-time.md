# WMS Inventory Position At Time View Documentation

## View: `wms_inventory_position_at_time`

### Overview
The WMS Inventory Position At Time view provides point-in-time inventory positions with full enrichment from handling units, storage bins, and SKU data. This parameterized view combines efficient adaptive snapshots with real-time events to deliver accurate inventory positions for any historical or current timestamp.

### View Structure
- **Type**: Parameterized View (requires `wh_id` and `target_time` parameters)
- **Architecture**: 2-tier system combining adaptive snapshots + recent events
- **Performance**: Optimized for fast point-in-time queries across any time period

### Parameters
| Parameter | Type | Description | Required |
|-----------|------|-------------|----------|
| `wh_id` | Int64 | Warehouse identifier | Yes |
| `target_time` | DateTime64(3) | Target timestamp for inventory position | Yes |

## Column Reference

### Core Inventory Identifiers
| Column | Type | Description |
|--------|------|-------------|
| `wh_id` | Int64 | Warehouse identifier |
| `hu_id` | String | Handling unit identifier |
| `hu_code` | String | Handling unit code |
| `sku_id` | String | SKU identifier |
| `uom` | String | Unit of measure |
| `bucket` | String | Inventory bucket/category |
| `batch` | String | Batch identifier |
| `price` | String | Price bucket |
| `inclusion_status` | String | Inclusion status for inventory |
| `locked_by_task_id` | String | Task that has locked this inventory |
| `lock_mode` | String | Lock mode (shared/exclusive) |
| `quant_iloc` | String | Inventory location |

### Quantity & Events
| Column | Type | Description |
|--------|------|-------------|
| `quantity` | Int64 | Current quantity at target time |
| `total_events` | UInt64 | Total number of events up to target time |
| `last_update_time` | DateTime64(3) | Latest event timestamp |

### Event Context
| Column | Type | Description |
|--------|------|-------------|
| `hu_event_id` | String | Latest handling unit event ID |
| `quant_event_id` | String | Latest quantity event ID |
| `session_id` | String | Associated session ID |
| `task_id` | String | Associated task ID |
| `correlation_id` | String | Event correlation ID |

### Handling Unit Details
| Column | Type | Description |
|--------|------|-------------|
| `hu_state` | String | Handling unit state |
| `hu_attrs` | String | Handling unit attributes (JSON) |
| `hu_created_at` | DateTime64(3) | HU creation timestamp |
| `hu_updated_at` | DateTime64(3) | HU last update timestamp |
| `hu_kind_code` | String | Handling unit kind code |
| `hu_kind_name` | String | Handling unit kind name |
| `hu_kind_max_volume` | Float64 | Maximum volume capacity |
| `hu_kind_max_weight` | Float64 | Maximum weight capacity |

### Storage Location Details
| Column | Type | Description |
|--------|------|-------------|
| `storage_bin_code` | String | Storage bin code |
| `storage_bin_description` | String | Storage bin description |
| `storage_aisle` | String | Storage aisle |
| `storage_bay` | String | Storage bay |
| `storage_level` | String | Storage level |
| `storage_zone_code` | String | Storage zone code |
| `storage_area_code` | String | Storage area code |

### SKU Details
| Column | Type | Description |
|--------|------|-------------|
| `sku_code` | String | SKU code |
| `sku_name` | String | SKU name |
| `sku_description` | String | SKU description |
| `sku_category` | String | SKU category |
| `sku_brand` | String | SKU brand |
| `sku_product` | String | SKU product |
| `sku_fulfillment_type` | String | Fulfillment type |
| `sku_inventory_type` | String | Inventory type |
| `sku_shelf_life` | Int32 | Shelf life in days |

### SKU UOM Hierarchy (L0-L3)
Each level (L0, L1, L2, L3) contains:
- `sku_l{X}_name` - UOM level name
- `sku_l{X}_units` - Units at this level
- `sku_l{X}_weight` - Weight per unit
- `sku_l{X}_volume` - Volume per unit
- `sku_l{X}_package_type` - Package type
- `sku_l{X}_length/width/height` - Dimensions

### Query Metadata
| Column | Type | Description |
|--------|------|-------------|
| `query_time` | DateTime64(3) | Target time used for the query |
| `base_snapshot_time` | DateTime64(3) | Snapshot time used as baseline |

## Best Practices

### Always Use Parameters
The view requires both parameters - ensure they're provided:

```sql
-- ✅ GOOD: Parameterized view usage
SELECT sku_code, sku_category, SUM(quantity) as total_qty
FROM wms_inventory_position_at_time(
    wh_id = 123, 
    target_time = '2024-01-15 14:30:00'
)
WHERE quantity > 0
GROUP BY sku_code, sku_category
ORDER BY total_qty DESC;

-- ❌ BAD: Missing parameters - will cause error
SELECT * FROM wms_inventory_position_at_time WHERE quantity > 0;
```

### Efficient Time-Based Queries
Use appropriate target times for your analysis needs:

```sql
-- Current inventory position
SELECT * FROM wms_inventory_position_at_time(
    wh_id = 123, 
    target_time = now()
)
WHERE quantity > 0;

-- Inventory position at end of business yesterday
SELECT * FROM wms_inventory_position_at_time(
    wh_id = 123, 
    target_time = toDateTime(yesterday()) + INTERVAL 18 HOUR
)
WHERE quantity > 0;
```

### Filter Non-Zero Quantities
Most queries should filter out zero quantities:

```sql
-- ✅ GOOD: Filter positive quantities
SELECT sku_category, COUNT(*) as sku_count, SUM(quantity) as total_qty
FROM wms_inventory_position_at_time(wh_id = 123, target_time = now())
WHERE quantity > 0
GROUP BY sku_category;
```

## Sample Queries

### 1. Current Inventory Summary by Category
```sql
SELECT 
    sku_category,
    sku_brand,
    COUNT(DISTINCT sku_code) as unique_skus,
    COUNT(DISTINCT hu_code) as unique_handling_units,
    SUM(quantity) as total_quantity,
    SUM(sku_l0_weight * quantity) as total_weight,
    AVG(quantity) as avg_quantity_per_position
FROM wms_inventory_position_at_time(
    wh_id = 123, 
    target_time = now()
)
WHERE quantity > 0
  AND sku_category != ''
GROUP BY sku_category, sku_brand
ORDER BY total_quantity DESC;
```

### 2. Historical Inventory Comparison
```sql
SELECT 
    'Current' as time_period,
    COUNT(*) as positions,
    SUM(quantity) as total_quantity,
    COUNT(DISTINCT sku_code) as unique_skus
FROM wms_inventory_position_at_time(wh_id = 123, target_time = now())
WHERE quantity > 0

UNION ALL

SELECT 
    'Last Week' as time_period,
    COUNT(*) as positions,
    SUM(quantity) as total_quantity,
    COUNT(DISTINCT sku_code) as unique_skus
FROM wms_inventory_position_at_time(
    wh_id = 123, 
    target_time = now() - INTERVAL 7 DAY
)
WHERE quantity > 0

ORDER BY time_period;
```

### 3. Zone Utilization Analysis
```sql
SELECT 
    storage_zone_code,
    storage_area_code,
    COUNT(*) as inventory_positions,
    SUM(quantity) as total_quantity,
    COUNT(DISTINCT storage_bin_code) as bins_with_inventory,
    SUM(sku_l0_volume * quantity) as total_volume_used,
    AVG(quantity) as avg_qty_per_position
FROM wms_inventory_position_at_time(
    wh_id = 123, 
    target_time = now()
)
WHERE quantity > 0
  AND storage_zone_code != ''
GROUP BY storage_zone_code, storage_area_code
ORDER BY total_quantity DESC;
```

### 4. SKU Inventory Details
```sql
SELECT 
    sku_code,
    sku_name,
    sku_category,
    COUNT(*) as inventory_positions,
    SUM(quantity) as total_quantity,
    COUNT(DISTINCT storage_bin_code) as bins_used,
    STRING_AGG(DISTINCT storage_zone_code, ', ') as zones,
    MIN(last_update_time) as earliest_activity,
    MAX(last_update_time) as latest_activity
FROM wms_inventory_position_at_time(
    wh_id = 123, 
    target_time = now()
)
WHERE quantity > 0
  AND sku_code = 'SKU001'
GROUP BY sku_code, sku_name, sku_category
ORDER BY total_quantity DESC;
```

### 5. End-of-Day Inventory Snapshot
```sql
SELECT 
    sku_category,
    SUM(quantity) as eod_quantity,
    COUNT(DISTINCT sku_code) as sku_count,
    SUM(sku_l0_weight * quantity) as total_weight_kg,
    SUM(sku_l0_volume * quantity) as total_volume_cc,
    COUNT(DISTINCT hu_code) as unique_hus
FROM wms_inventory_position_at_time(
    wh_id = 123,
    target_time = toDateTime(today()) + INTERVAL 23 HOUR + INTERVAL 59 MINUTE
)
WHERE quantity > 0
  AND sku_l0_weight > 0
  AND sku_l0_volume > 0
GROUP BY sku_category
ORDER BY eod_quantity DESC;
```

### 6. Handling Unit Inventory Analysis
```sql
SELECT 
    hu_code,
    hu_kind_code,
    hu_kind_name,
    COUNT(*) as sku_positions,
    SUM(quantity) as total_quantity,
    COUNT(DISTINCT sku_code) as unique_skus,
    storage_bin_code,
    storage_zone_code,
    last_update_time
FROM wms_inventory_position_at_time(
    wh_id = 123, 
    target_time = now()
)
WHERE quantity > 0
  AND hu_code != ''
GROUP BY hu_code, hu_kind_code, hu_kind_name, storage_bin_code, 
         storage_zone_code, last_update_time
ORDER BY total_quantity DESC
LIMIT 50;
```

### 7. Batch Tracking Analysis
```sql
SELECT 
    sku_code,
    sku_name,
    batch,
    SUM(quantity) as batch_quantity,
    COUNT(*) as positions_count,
    COUNT(DISTINCT storage_bin_code) as bins_spread,
    MIN(last_update_time) as earliest_update,
    MAX(last_update_time) as latest_update
FROM wms_inventory_position_at_time(
    wh_id = 123, 
    target_time = now()
)
WHERE quantity > 0
  AND batch != ''
  AND sku_category = 'Food'
GROUP BY sku_code, sku_name, batch
HAVING batch_quantity > 100
ORDER BY sku_code, batch_quantity DESC;
```

### 8. Locked Inventory Analysis
```sql
SELECT 
    locked_by_task_id,
    lock_mode,
    COUNT(*) as locked_positions,
    SUM(quantity) as locked_quantity,
    COUNT(DISTINCT sku_code) as unique_skus_locked,
    COUNT(DISTINCT hu_code) as unique_hus_locked
FROM wms_inventory_position_at_time(
    wh_id = 123, 
    target_time = now()
)
WHERE quantity > 0
  AND locked_by_task_id != ''
GROUP BY locked_by_task_id, lock_mode
ORDER BY locked_quantity DESC;
```

## Performance Notes
- Uses efficient 2-tier architecture: adaptive snapshots + recent events
- Automatically selects optimal snapshot as baseline
- Parameterized design enables flexible time-based queries
- Aggregates duplicate positions using argMax for latest dimensional data
- Filters out zero quantities by default for better performance
- Query time and base snapshot time included for transparency