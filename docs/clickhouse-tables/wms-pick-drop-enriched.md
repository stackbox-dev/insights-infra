# WMS Pick Drop Enriched Table Documentation

## Table: `wms_pick_drop_enriched`

### Overview
The WMS Pick Drop Enriched table contains comprehensive pick-drop operations data enriched with worker information, handling unit details, and SKU master data. This table enables detailed analysis of warehouse picking and dropping operations with full dimensional context.

### Engine & Partitioning
- **Engine**: `ReplacingMergeTree(event_time)`
- **Partitioning**: Monthly by `toYYYYMM(pick_item_created_at)`
- **Ordering**: `(wh_id, pick_item_created_at, pick_item_id, drop_item_id)`
- **Deduplication**: Uses `deduplicate_merge_projection_mode = 'drop'`

## Column Reference

### Core Identifiers
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `wh_id` | Int64 | 0 | Warehouse ID |
| `principal_id` | Int64 | 0 | Principal/tenant ID |
| `pick_item_id` | String | '' | Unique pick item identifier |
| `drop_item_id` | String | '' | Unique drop item identifier |

### Pick Item Core Fields
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `picked_bin` | String | '' | Source bin where item was picked |
| `picked_sku_id` | String | '' | SKU identifier that was picked |
| `picked_batch` | String | '' | Batch identifier |
| `picked_uom` | String | '' | Unit of measure |
| `overall_qty` | Int32 | 0 | Overall quantity to be picked |
| `qty` | Int32 | 0 | Target quantity for this pick |
| `picked_qty` | Int32 | 0 | Actual quantity picked |
| `hu_code` | String | '' | Handling unit code |
| `destination_bin_code` | String | '' | Destination bin code |

### Pick Timing Fields
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `pick_item_created_at` | DateTime64(3) | '1970-01-01 00:00:00' | Pick item creation time |
| `picked_at` | DateTime64(3) | '1970-01-01 00:00:00' | Actual pick timestamp |
| `moved_at` | DateTime64(3) | '1970-01-01 00:00:00' | Movement timestamp |
| `processed_at` | DateTime64(3) | '1970-01-01 00:00:00' | Processing timestamp |
| `pick_item_updated_at` | DateTime64(3) | '1970-01-01 00:00:00' | Last update timestamp |

### Pick Worker & Session
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `picked_by_worker_id` | String | '' | Worker ID who performed pick |
| `session_id` | String | '' | Session identifier |
| `task_id` | String | '' | Task identifier |
| `lm_trip_id` | String | '' | Labor management trip ID |

### Pick Handling Unit Details
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `picked_hu_eq_uom` | String | '' | Pick HU equivalent UOM |
| `picked_has_inner_hus` | Bool | false | Has inner handling units |
| `picked_inner_hu_eq_uom` | String | '' | Inner HU equivalent UOM |
| `scan_source_hu_kind` | String | '' | Scanned source HU kind |
| `pick_source_hu_kind` | String | '' | Pick source HU kind |
| `carrier_hu_kind` | String | '' | Carrier HU kind |
| `hu_kind` | String | '' | Handling unit kind |

### Drop Item Core Fields
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `dropped_sku_id` | String | '' | SKU identifier that was dropped |
| `dropped_batch` | String | '' | Dropped batch identifier |
| `dropped_uom` | String | '' | Dropped unit of measure |
| `drop_bucket` | String | '' | Drop bucket/category |
| `picked_hu_code` | String | '' | Picked handling unit code |
| `dropped_bin_code` | String | '' | Bin where item was dropped |
| `dropped_qty` | Int32 | 0 | Actual quantity dropped |

### Drop Timing Fields
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `dropped_at` | DateTime64(3) | '1970-01-01 00:00:00' | Actual drop timestamp |
| `drop_item_updated_at` | DateTime64(3) | '1970-01-01 00:00:00' | Drop item last update |
| `drop_created_at` | DateTime64(3) | '1970-01-01 00:00:00' | Drop item creation time |
| `processed_for_loading_at` | DateTime64(3) | '1970-01-01 00:00:00' | Processed for loading timestamp |
| `processed_on_drop_at` | DateTime64(3) | '1970-01-01 00:00:00' | Processed on drop timestamp |

### Drop Worker & Handling
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `dropped_by_worker_id` | String | '' | Worker ID who performed drop |
| `drop_hu_in_bin` | Bool | false | Drop HU in bin flag |
| `scan_dest_hu` | Bool | false | Scan destination HU flag |
| `allow_hu_break` | Bool | false | Allow HU break flag |
| `dropped_has_inner_hus` | Bool | false | Dropped has inner HUs |
| `hu_broken` | Bool | false | HU broken flag |

### Worker Enrichment
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `worker_code` | String | '' | Worker code |
| `worker_name` | String | '' | Worker name |
| `worker_phone` | String | '' | Worker phone |
| `worker_supervisor` | Bool | false | Is worker supervisor |
| `worker_active` | Bool | false | Worker active status |

### SKU Enrichment (from picked_sku_id)
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `sku_category` | String | '' | SKU category |
| `sku_product` | String | '' | SKU product |
| `sku_brand` | String | '' | SKU brand |
| `sku_code` | String | '' | SKU code |
| `sku_name` | String | '' | SKU name |
| `sku_description` | String | '' | SKU description |
| `sku_fulfillment_type` | String | '' | Fulfillment type |
| `sku_inventory_type` | String | '' | Inventory type |
| `sku_shelf_life` | Int32 | 0 | Shelf life in days |
| `sku_handling_unit_type` | String | '' | Handling unit type |

### SKU UOM Hierarchy (L0-L3)
Each level contains:
- `sku_l{X}_name` - UOM level name
- `sku_l{X}_units` - Units at this level
- `sku_l{X}_weight` - Weight per unit (Float64)
- `sku_l{X}_volume` - Volume per unit (Float64)
- `sku_l{X}_package_type` - Package type
- `sku_l{X}_length/width/height` - Dimensions (Float64)
- `sku_l{X}_itf_code` - ITF code

### Additional Metadata
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `event_time` | DateTime64(3) | '1970-01-01 00:00:00' | Computed event time |
| `mapping_id` | String | '' | Pick-drop mapping identifier |
| `mapping_created_at` | DateTime64(3) | '1970-01-01 00:00:00' | Mapping creation time |

## Indexes
The table includes bloom filter indexes on:
- `principal_id`, `picked_sku_id`, `session_id`, `task_id`, `worker_code`
- `sku_code`, `sku_category`, `sku_brand`
- MinMax indexes on timestamp fields for efficient range queries

## Best Practices

### Partition Pruning
Always include `pick_item_created_at` filters:

```sql
-- ✅ GOOD: Uses partition pruning
SELECT worker_code, COUNT(*) as pick_count
FROM wms_pick_drop_enriched
WHERE pick_item_created_at >= '2024-01-01 00:00:00'
  AND pick_item_created_at < '2024-02-01 00:00:00'
  AND wh_id = 123
GROUP BY worker_code;

-- ❌ BAD: No timestamp filter - scans all partitions
SELECT COUNT(*) FROM wms_pick_drop_enriched WHERE wh_id = 123;
```

### Performance Filtering
Use indexed columns for filtering:
```sql
-- ✅ GOOD: Uses indexed columns
SELECT *
FROM wms_pick_drop_enriched
WHERE pick_item_created_at >= '2024-01-01'
  AND sku_category = 'Electronics'
  AND worker_code = 'W001';
```

## Sample Queries

### 1. Worker Productivity Analysis
```sql
SELECT 
    worker_code,
    worker_name,
    COUNT(*) as total_picks,
    SUM(picked_qty) as total_quantity,
    AVG(picked_qty) as avg_qty_per_pick,
    COUNT(DISTINCT toDate(picked_at)) as working_days,
    COUNT(*) / COUNT(DISTINCT toDate(picked_at)) as picks_per_day
FROM wms_pick_drop_enriched
WHERE pick_item_created_at >= '2024-01-01 00:00:00'
  AND pick_item_created_at < '2024-02-01 00:00:00'
  AND wh_id = 123
  AND picked_at > toDateTime64('1970-01-01 00:00:00', 3)
GROUP BY worker_code, worker_name
HAVING total_picks >= 10
ORDER BY picks_per_day DESC;
```

### 2. SKU Pick Frequency Analysis
```sql
SELECT 
    sku_code,
    sku_name,
    sku_category,
    sku_brand,
    COUNT(*) as pick_frequency,
    SUM(picked_qty) as total_picked,
    AVG(picked_qty) as avg_qty_per_pick,
    COUNT(DISTINCT worker_code) as unique_workers
FROM wms_pick_drop_enriched
WHERE pick_item_created_at >= '2024-01-01 00:00:00'
  AND pick_item_created_at < '2024-02-01 00:00:00'
  AND wh_id = 123
  AND picked_qty > 0
GROUP BY sku_code, sku_name, sku_category, sku_brand
ORDER BY pick_frequency DESC
LIMIT 50;
```

### 3. Pick-Drop Timing Analysis
```sql
SELECT 
    toHour(picked_at) as hour_of_day,
    COUNT(*) as pick_count,
    AVG(dateDiff('second', pick_item_created_at, picked_at)) as avg_pick_time_seconds,
    AVG(dateDiff('second', picked_at, dropped_at)) as avg_move_time_seconds,
    AVG(picked_qty) as avg_quantity
FROM wms_pick_drop_enriched
WHERE pick_item_created_at >= '2024-01-01 00:00:00'
  AND pick_item_created_at < '2024-02-01 00:00:00'
  AND wh_id = 123
  AND picked_at > toDateTime64('1970-01-01 00:00:00', 3)
  AND dropped_at > toDateTime64('1970-01-01 00:00:00', 3)
GROUP BY hour_of_day
ORDER BY hour_of_day;
```

### 4. Category Performance Summary
```sql
SELECT 
    sku_category,
    sku_brand,
    COUNT(*) as total_picks,
    SUM(picked_qty) as total_quantity,
    COUNT(DISTINCT sku_code) as unique_skus,
    COUNT(DISTINCT worker_code) as unique_workers,
    AVG(dateDiff('second', pick_item_created_at, picked_at)) as avg_pick_time_sec,
    SUM(sku_l0_weight * picked_qty) as total_weight_picked
FROM wms_pick_drop_enriched
WHERE pick_item_created_at >= '2024-01-01 00:00:00'
  AND pick_item_created_at < '2024-02-01 00:00:00'
  AND wh_id = 123
  AND picked_qty > 0
  AND sku_l0_weight > 0
GROUP BY sku_category, sku_brand
ORDER BY total_picks DESC;
```

### 5. Handling Unit Analysis
```sql
SELECT 
    hu_kind,
    carrier_hu_kind,
    COUNT(*) as pick_count,
    COUNT(DISTINCT hu_code) as unique_hus,
    AVG(picked_qty) as avg_qty_per_pick,
    COUNT(CASE WHEN picked_has_inner_hus = true THEN 1 END) as picks_with_inner_hus
FROM wms_pick_drop_enriched
WHERE pick_item_created_at >= '2024-01-01 00:00:00'
  AND pick_item_created_at < '2024-02-01 00:00:00'
  AND wh_id = 123
  AND hu_kind != ''
GROUP BY hu_kind, carrier_hu_kind
ORDER BY pick_count DESC;
```

### 6. Daily Pick Trends
```sql
SELECT 
    toDate(pick_item_created_at) as pick_date,
    COUNT(*) as total_picks,
    SUM(picked_qty) as total_quantity,
    COUNT(DISTINCT worker_code) as active_workers,
    COUNT(DISTINCT sku_code) as unique_skus_picked,
    AVG(picked_qty) as avg_qty_per_pick
FROM wms_pick_drop_enriched
WHERE pick_item_created_at >= '2024-01-01 00:00:00'
  AND pick_item_created_at < '2024-02-01 00:00:00'
  AND wh_id = 123
  AND picked_qty > 0
GROUP BY pick_date
ORDER BY pick_date;
```

### 7. Session Analysis
```sql
SELECT 
    session_id,
    task_id,
    COUNT(*) as picks_in_session,
    SUM(picked_qty) as total_quantity,
    MIN(pick_item_created_at) as session_start,
    MAX(picked_at) as session_end,
    dateDiff('minute', MIN(pick_item_created_at), MAX(picked_at)) as session_duration_minutes,
    COUNT(DISTINCT sku_code) as unique_skus
FROM wms_pick_drop_enriched
WHERE pick_item_created_at >= '2024-01-01 00:00:00'
  AND pick_item_created_at < '2024-02-01 00:00:00'
  AND wh_id = 123
  AND session_id != ''
GROUP BY session_id, task_id
HAVING picks_in_session >= 5
ORDER BY session_duration_minutes DESC;
```

## Performance Notes
- Monthly partitioning optimizes queries with time-range filters
- Bloom filter indexes enable fast filtering on string fields
- Use `pick_item_created_at` for partition pruning
- SKU enrichment provides dimensional context without additional JOINs
- Worker enrichment enables direct productivity analysis