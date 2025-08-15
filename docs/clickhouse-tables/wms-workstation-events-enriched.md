# WMS Workstation Events Enriched Table Documentation

## Table: `wms_workstation_events_enriched`

### Overview
The WMS Workstation Events Enriched table contains comprehensive workstation event data enriched with handling unit details, storage bin information, and SKU master data. This table enables detailed analysis of workstation operations, user interactions, and material flow with full dimensional context.

### Engine & Partitioning
- **Engine**: `ReplacingMergeTree(event_timestamp)`
- **Partitioning**: Monthly by `toYYYYMM(event_timestamp)`
- **Ordering**: `(wh_id, event_type, event_source_id)`
- **TTL**: `toDateTime(deactivated_at) + INTERVAL 0 SECOND DELETE`
- **Deduplication**: Uses `deduplicate_merge_projection_mode = 'drop'`

## Column Reference

### Core Event Fields
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `event_type` | String | - | Type of workstation event |
| `event_source_id` | String | - | Unique event source identifier |
| `event_timestamp` | DateTime64(3) | - | Event occurrence timestamp |
| `created_at` | DateTime64(3) | - | Event creation timestamp |
| `wh_id` | Int64 | - | Warehouse identifier |

### Event Context
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `sku_id` | String | - | SKU involved in the event |
| `hu_id` | String | - | Handling unit involved |
| `hu_code` | String | - | Handling unit code |
| `batch_id` | String | - | Batch identifier |
| `user_id` | String | - | User who triggered the event |
| `task_id` | String | - | Associated task ID |
| `session_id` | String | - | Session identifier |
| `bin_id` | String | - | Storage bin involved |

### Event Quantities
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `primary_quantity` | Int64 | - | Primary quantity involved |
| `secondary_quantity` | Int64 | - | Secondary quantity |
| `tertiary_quantity` | Int64 | - | Tertiary quantity |
| `price` | String | - | Price information |
| `status_or_bucket` | String | - | Status or bucket category |
| `reason` | String | - | Event reason |
| `sub_reason` | String | - | Sub-reason for the event |

### Event Lifecycle
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `deactivated_at` | DateTime64(3) | - | Event deactivation timestamp |

### Handling Unit Enrichment
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `hu_enriched_code` | String | '' | Enriched handling unit code |
| `hu_kind_id` | String | '' | Handling unit kind ID |
| `hu_session_id` | String | '' | HU session ID |
| `hu_task_id` | String | '' | HU task ID |
| `hu_storage_id` | String | '' | HU storage location ID |
| `hu_outer_hu_id` | String | '' | Outer handling unit ID |
| `hu_state` | String | '' | Handling unit state |
| `hu_attrs` | String | '{}' | HU attributes (JSON) |
| `hu_lock_task_id` | String | '' | Task that has locked the HU |
| `hu_effective_storage_id` | String | '' | Effective storage location |
| `hu_created_at` | DateTime64(3) | '1970-01-01 00:00:00' | HU creation timestamp |
| `hu_updated_at` | DateTime64(3) | '1970-01-01 00:00:00' | HU last update timestamp |

### Storage Bin Enrichment
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `bin_code` | String | '' | Storage bin code |
| `bin_created_at` | DateTime64(3) | '1970-01-01 00:00:00' | Bin creation timestamp |
| `bin_updated_at` | DateTime64(3) | '1970-01-01 00:00:00' | Bin last update timestamp |
| `bin_description` | String | '' | Bin description |
| `bin_status` | String | '' | Bin status |
| `bin_hu_id` | String | '' | HU currently in bin |
| `multi_sku` | Bool | false | Bin allows multiple SKUs |
| `multi_batch` | Bool | false | Bin allows multiple batches |
| `picking_position` | Int32 | 0 | Picking position priority |
| `putaway_position` | Int32 | 0 | Putaway position priority |
| `bin_rank` | Int32 | 0 | Bin rank/priority |

### Storage Location Details
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `aisle` | String | '' | Storage aisle |
| `bay` | String | '' | Storage bay |
| `level` | String | '' | Storage level |
| `bin_position` | String | '' | Position within location |
| `depth` | String | '' | Depth position |
| `bin_type_code` | String | '' | Bin type code |
| `zone_id` | String | '' | Zone identifier |
| `zone_code` | String | '' | Zone code |
| `zone_description` | String | '' | Zone description |
| `area_id` | String | '' | Area identifier |
| `area_code` | String | '' | Area code |
| `area_description` | String | '' | Area description |

### Storage Capacity
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `x1`, `y1` | Float64 | 0 | Position coordinates |
| `max_volume_in_cc` | Float64 | 0 | Maximum volume in cubic centimeters |
| `max_weight_in_kg` | Float64 | 0 | Maximum weight in kilograms |
| `pallet_capacity` | Int32 | 0 | Pallet capacity |

### SKU Enrichment
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `sku_code` | String | '' | SKU code |
| `sku_name` | String | '' | SKU name |
| `sku_short_description` | String | '' | Short description |
| `sku_description` | String | '' | Full description |
| `sku_category` | String | '' | SKU category |
| `sku_category_group` | String | '' | Category group |
| `sku_product` | String | '' | Product name |
| `sku_product_id` | String | '' | Product identifier |
| `sku_brand` | String | '' | Brand name |
| `sku_sub_brand` | String | '' | Sub-brand |
| `sku_fulfillment_type` | String | '' | Fulfillment type |
| `sku_inventory_type` | String | '' | Inventory type |
| `sku_shelf_life` | Int32 | 0 | Shelf life in days |
| `sku_handling_unit_type` | String | '' | Handling unit type |
| `sku_active` | Bool | false | SKU active status |

### SKU Identifiers & Tags
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `sku_identifier1`, `sku_identifier2` | String | '' | Custom identifiers |
| `sku_tag1` through `sku_tag5` | String | '' | Custom tags |

### SKU UOM Hierarchy (L0-L3)
Each level contains:
- `sku_l{X}_name` - UOM level name
- `sku_l{X}_units` - Units at this level (Int32)
- `sku_l{X}_weight` - Weight per unit (Float64)
- `sku_l{X}_volume` - Volume per unit (Float64)
- `sku_l{X}_package_type` - Package type
- `sku_l{X}_length/width/height` - Dimensions (Float64)
- `sku_l{X}_itf_code` - ITF code

### SKU Configuration
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `sku_cases_per_layer` | Int32 | 0 | Cases per layer |
| `sku_layers` | Int32 | 0 | Number of layers |
| `sku_avg_l0_per_put` | Int32 | 0 | Average L0 units per putaway |
| `sku_combined_classification` | String | '' | Combined classification (JSON) |

## Indexes
The table includes multiple indexes for optimal query performance:
- **MinMax indexes**: `wh_id`, `event_timestamp`
- **Bloom filter indexes**: `event_type`, `user_id`, `task_id`, `session_id`, `sku_id`, `hu_id`, `bin_id`, `bin_code`, `sku_code`

## Best Practices

### Partition Pruning
Always include `event_timestamp` filters for optimal performance:

```sql
-- ✅ GOOD: Uses partition pruning
SELECT event_type, COUNT(*) as event_count
FROM wms_workstation_events_enriched
WHERE event_timestamp >= '2024-01-01 00:00:00'
  AND event_timestamp < '2024-02-01 00:00:00'
  AND wh_id = 123
GROUP BY event_type;

-- ❌ BAD: No timestamp filter - scans all partitions
SELECT COUNT(*) FROM wms_workstation_events_enriched WHERE wh_id = 123;
```

### Use Indexed Columns
Leverage bloom filter indexes for fast filtering:
```sql
-- ✅ GOOD: Uses indexed columns
SELECT *
FROM wms_workstation_events_enriched
WHERE event_timestamp >= '2024-01-01'
  AND event_type = 'PICK_COMPLETE'
  AND sku_code = 'SKU001';
```

### TTL Considerations
Be aware of the TTL policy when querying deactivated events:
```sql
-- Include active events only (deactivated_at is null or future)
SELECT *
FROM wms_workstation_events_enriched
WHERE event_timestamp >= '2024-01-01'
  AND (deactivated_at IS NULL OR deactivated_at > now());
```

## Sample Queries

### 1. Event Type Distribution
```sql
SELECT 
    event_type,
    COUNT(*) as event_count,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT sku_code) as unique_skus,
    AVG(primary_quantity) as avg_quantity
FROM wms_workstation_events_enriched
WHERE event_timestamp >= '2024-01-01 00:00:00'
  AND event_timestamp < '2024-02-01 00:00:00'
  AND wh_id = 123
GROUP BY event_type
ORDER BY event_count DESC;
```

### 2. User Activity Analysis
```sql
SELECT 
    user_id,
    COUNT(*) as total_events,
    COUNT(DISTINCT event_type) as unique_event_types,
    COUNT(DISTINCT toDate(event_timestamp)) as active_days,
    MIN(event_timestamp) as first_event,
    MAX(event_timestamp) as last_event,
    SUM(primary_quantity) as total_quantity_handled
FROM wms_workstation_events_enriched
WHERE event_timestamp >= '2024-01-01 00:00:00'
  AND event_timestamp < '2024-02-01 00:00:00'
  AND wh_id = 123
GROUP BY user_id
HAVING total_events >= 10
ORDER BY total_events DESC;
```

### 3. SKU Event Analysis
```sql
SELECT 
    sku_code,
    sku_name,
    sku_category,
    sku_brand,
    COUNT(*) as event_count,
    COUNT(DISTINCT event_type) as event_types,
    SUM(primary_quantity) as total_quantity,
    COUNT(DISTINCT bin_code) as unique_bins_used
FROM wms_workstation_events_enriched
WHERE event_timestamp >= '2024-01-01 00:00:00'
  AND event_timestamp < '2024-02-01 00:00:00'
  AND wh_id = 123
  AND sku_code != ''
GROUP BY sku_code, sku_name, sku_category, sku_brand
ORDER BY event_count DESC
LIMIT 50;
```

### 4. Hourly Activity Pattern
```sql
SELECT 
    toHour(event_timestamp) as hour_of_day,
    COUNT(*) as event_count,
    COUNT(DISTINCT user_id) as active_users,
    AVG(primary_quantity) as avg_quantity,
    COUNT(DISTINCT event_type) as unique_event_types
FROM wms_workstation_events_enriched
WHERE event_timestamp >= '2024-01-01 00:00:00'
  AND event_timestamp < '2024-02-01 00:00:00'
  AND wh_id = 123
GROUP BY hour_of_day
ORDER BY hour_of_day;
```

### 5. Storage Area Activity
```sql
SELECT 
    area_code,
    area_description,
    zone_code,
    COUNT(*) as event_count,
    COUNT(DISTINCT bin_code) as bins_used,
    COUNT(DISTINCT sku_code) as unique_skus,
    SUM(primary_quantity) as total_quantity
FROM wms_workstation_events_enriched
WHERE event_timestamp >= '2024-01-01 00:00:00'
  AND event_timestamp < '2024-02-01 00:00:00'
  AND wh_id = 123
  AND area_code != ''
GROUP BY area_code, area_description, zone_code
ORDER BY event_count DESC;
```

### 6. Task and Session Analysis
```sql
SELECT 
    task_id,
    session_id,
    COUNT(*) as events_in_task,
    COUNT(DISTINCT event_type) as event_types,
    COUNT(DISTINCT user_id) as users_involved,
    MIN(event_timestamp) as task_start,
    MAX(event_timestamp) as task_end,
    dateDiff('minute', MIN(event_timestamp), MAX(event_timestamp)) as duration_minutes
FROM wms_workstation_events_enriched
WHERE event_timestamp >= '2024-01-01 00:00:00'
  AND event_timestamp < '2024-02-01 00:00:00'
  AND wh_id = 123
  AND task_id != ''
GROUP BY task_id, session_id
HAVING events_in_task >= 5
ORDER BY duration_minutes DESC;
```

### 7. Handling Unit Movement Tracking
```sql
SELECT 
    hu_code,
    hu_kind_id,
    COUNT(*) as movement_events,
    COUNT(DISTINCT bin_code) as bins_visited,
    COUNT(DISTINCT user_id) as handlers,
    MIN(event_timestamp) as first_event,
    MAX(event_timestamp) as last_event,
    arrayStringConcat(groupUniqArray(bin_code), ' -> ') as bin_sequence
FROM wms_workstation_events_enriched
WHERE event_timestamp >= '2024-01-01 00:00:00'
  AND event_timestamp < '2024-02-01 00:00:00'
  AND wh_id = 123
  AND hu_code != ''
  AND bin_code != ''
GROUP BY hu_code, hu_kind_id
HAVING movement_events >= 3
ORDER BY movement_events DESC
LIMIT 20;
```

### 8. Event Reasons Analysis
```sql
SELECT 
    event_type,
    reason,
    sub_reason,
    COUNT(*) as occurrence_count,
    COUNT(DISTINCT user_id) as unique_users,
    AVG(primary_quantity) as avg_quantity
FROM wms_workstation_events_enriched
WHERE event_timestamp >= '2024-01-01 00:00:00'
  AND event_timestamp < '2024-02-01 00:00:00'
  AND wh_id = 123
  AND reason != ''
GROUP BY event_type, reason, sub_reason
ORDER BY occurrence_count DESC;
```

## Performance Notes
- Monthly partitioning enables efficient time-range queries
- Multiple bloom filter indexes support fast multi-dimensional filtering
- TTL automatically removes deactivated events to maintain performance
- Enrichment provides full dimensional context without additional JOINs
- Use `event_timestamp` filters for optimal partition pruning