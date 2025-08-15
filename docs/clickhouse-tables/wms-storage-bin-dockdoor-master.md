# WMS Storage Bin Dockdoor Master Table Documentation

## Table: `wms_storage_bin_dockdoor_master`

### Overview
The WMS Storage Bin Dockdoor Master table provides mapping between storage bins and dock doors for inbound/outbound logistics and staging operations. This table enables efficient routing, capacity planning, and operational analysis for dock door management.

### Engine & Partitioning
- **Engine**: `ReplacingMergeTree(dockdoor_updated_at)`
- **Ordering**: `(bin_id, dockdoor_id)` - Composite unique key
- **No Partitioning**: Dimension table optimized for JOINs
- **Deduplication**: Uses `deduplicate_merge_projection_mode = 'drop'`

## Column Reference

### Core Identifiers
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `wh_id` | Int64 | - | Warehouse identifier |
| `bin_code` | String | - | Storage bin code |
| `dockdoor_code` | String | - | Dock door code |
| `bin_id` | String | '' | Unique bin identifier |
| `dockdoor_id` | String | '' | Unique dock door identifier |

### Dock Door Configuration
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `dockdoor_description` | String | '' | Dock door description |
| `usage` | String | '' | Usage type: INBOUND/OUTBOUND/BOTH |
| `active` | Bool | false | Dock door active status |
| `dock_handling_unit` | String | '' | Handling unit type for dock |
| `multi_trip` | Bool | false | Supports multiple trips |

### Capacity & Capabilities
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `max_queue` | Int64 | 0 | Maximum queue capacity |
| `allow_inbound` | Bool | false | Allows inbound operations |
| `allow_outbound` | Bool | false | Allows outbound operations |
| `allow_returns` | Bool | false | Allows return operations |
| `dockdoor_status` | String | '' | Current dock door status |

### Operational Constraints
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `incompatible_vehicle_types` | String | '' | Incompatible vehicle types (list as string) |
| `incompatible_load_types` | String | '' | Incompatible load types (list as string) |

### Location Information
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `dockdoor_x_coordinate` | Float64 | 0 | X-coordinate of dock door |
| `dockdoor_y_coordinate` | Float64 | 0 | Y-coordinate of dock door |
| `dockdoor_position_active` | Bool | false | Position information active |

### Timestamp Fields
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `bin_created_at` | DateTime64(3) | '1970-01-01 00:00:00' | Bin creation timestamp |
| `bin_updated_at` | DateTime64(3) | '1970-01-01 00:00:00' | Bin last update timestamp |
| `dockdoor_created_at` | DateTime64(3) | '1970-01-01 00:00:00' | Dock door creation timestamp |
| `dockdoor_updated_at` | DateTime64(3) | '1970-01-01 00:00:00' | Dock door last update timestamp |

## Indexes
The table includes indexes for optimal query performance:
- **MinMax index**: `wh_id`
- **Bloom filter indexes**: `bin_code`, `dockdoor_code`

## Best Practices

### Use for Staging Area Analysis
This table is ideal for analyzing staging areas and dock door utilization:

```sql
-- ✅ GOOD: Analyze dock door capacity utilization
SELECT 
    dockdoor_code,
    dockdoor_description,
    COUNT(*) as assigned_bins,
    SUM(max_queue) as total_queue_capacity,
    usage
FROM wms_storage_bin_dockdoor_master
WHERE wh_id = 123
  AND active = true
GROUP BY dockdoor_code, dockdoor_description, usage
ORDER BY total_queue_capacity DESC;
```

### Filter by Active Status
Always consider active dock doors for operational queries:
```sql
-- ✅ GOOD: Filter by active dock doors
SELECT *
FROM wms_storage_bin_dockdoor_master
WHERE wh_id = 123
  AND active = true;
```

### Usage Type Filtering
Filter by specific usage patterns:
```sql
-- Filter by inbound operations
SELECT *
FROM wms_storage_bin_dockdoor_master
WHERE wh_id = 123
  AND (usage = 'INBOUND' OR usage = 'BOTH')
  AND allow_inbound = true;
```

## Sample Queries

### 1. Dock Door Capacity Summary
```sql
SELECT 
    usage,
    COUNT(DISTINCT dockdoor_code) as dock_door_count,
    COUNT(*) as total_bin_mappings,
    SUM(max_queue) as total_queue_capacity,
    AVG(max_queue) as avg_queue_per_door,
    COUNT(CASE WHEN multi_trip = true THEN 1 END) as multi_trip_doors
FROM wms_storage_bin_dockdoor_master
WHERE wh_id = 123
  AND active = true
GROUP BY usage
ORDER BY total_queue_capacity DESC;
```

### 2. Inbound vs Outbound Capability Analysis
```sql
SELECT 
    dockdoor_code,
    dockdoor_description,
    usage,
    allow_inbound,
    allow_outbound,
    allow_returns,
    COUNT(*) as mapped_bins,
    max_queue,
    multi_trip,
    dockdoor_status
FROM wms_storage_bin_dockdoor_master
WHERE wh_id = 123
  AND active = true
GROUP BY dockdoor_code, dockdoor_description, usage, allow_inbound, 
         allow_outbound, allow_returns, max_queue, multi_trip, dockdoor_status
ORDER BY usage, mapped_bins DESC;
```

### 3. Dock Door Geographic Distribution
```sql
SELECT 
    dockdoor_code,
    dockdoor_x_coordinate,
    dockdoor_y_coordinate,
    COUNT(*) as mapped_bins,
    usage,
    max_queue,
    SQRT(POW(dockdoor_x_coordinate, 2) + POW(dockdoor_y_coordinate, 2)) as distance_from_origin
FROM wms_storage_bin_dockdoor_master
WHERE wh_id = 123
  AND active = true
  AND dockdoor_position_active = true
  AND dockdoor_x_coordinate > 0
  AND dockdoor_y_coordinate > 0
GROUP BY dockdoor_code, dockdoor_x_coordinate, dockdoor_y_coordinate, 
         usage, max_queue
ORDER BY distance_from_origin;
```

### 4. Vehicle and Load Type Constraints
```sql
SELECT 
    dockdoor_code,
    usage,
    incompatible_vehicle_types,
    incompatible_load_types,
    COUNT(*) as mapped_bins,
    max_queue
FROM wms_storage_bin_dockdoor_master
WHERE wh_id = 123
  AND active = true
  AND (incompatible_vehicle_types != '' OR incompatible_load_types != '')
GROUP BY dockdoor_code, usage, incompatible_vehicle_types, 
         incompatible_load_types, max_queue
ORDER BY dockdoor_code;
```

### 5. Dock Door Utilization by Bin Count
```sql
SELECT 
    dockdoor_code,
    dockdoor_description,
    usage,
    COUNT(DISTINCT bin_code) as unique_bins,
    max_queue,
    CASE 
        WHEN max_queue > 0 THEN ROUND(COUNT(DISTINCT bin_code) * 100.0 / max_queue, 2)
        ELSE 0 
    END as bin_to_capacity_ratio,
    multi_trip,
    dock_handling_unit
FROM wms_storage_bin_dockdoor_master
WHERE wh_id = 123
  AND active = true
GROUP BY dockdoor_code, dockdoor_description, usage, max_queue, 
         multi_trip, dock_handling_unit
HAVING unique_bins > 0
ORDER BY bin_to_capacity_ratio DESC;
```

### 6. Dock Door Status Analysis
```sql
SELECT 
    dockdoor_status,
    usage,
    COUNT(DISTINCT dockdoor_code) as door_count,
    COUNT(*) as total_bin_mappings,
    SUM(max_queue) as total_capacity,
    COUNT(CASE WHEN allow_inbound = true THEN 1 END) as inbound_capable,
    COUNT(CASE WHEN allow_outbound = true THEN 1 END) as outbound_capable,
    COUNT(CASE WHEN allow_returns = true THEN 1 END) as returns_capable
FROM wms_storage_bin_dockdoor_master
WHERE wh_id = 123
  AND active = true
GROUP BY dockdoor_status, usage
ORDER BY dockdoor_status, usage;
```

### 7. Multi-Trip Capability Analysis
```sql
SELECT 
    multi_trip,
    usage,
    COUNT(DISTINCT dockdoor_code) as dock_doors,
    COUNT(*) as bin_mappings,
    AVG(max_queue) as avg_queue_capacity,
    COUNT(CASE WHEN dock_handling_unit != '' THEN 1 END) as with_hu_specification
FROM wms_storage_bin_dockdoor_master
WHERE wh_id = 123
  AND active = true
GROUP BY multi_trip, usage
ORDER BY multi_trip DESC, usage;
```

### 8. Recent Changes Tracking
```sql
SELECT 
    dockdoor_code,
    bin_code,
    usage,
    active,
    dockdoor_updated_at,
    bin_updated_at,
    GREATEST(dockdoor_updated_at, bin_updated_at) as last_change,
    dateDiff('day', GREATEST(dockdoor_updated_at, bin_updated_at), now()) as days_since_change
FROM wms_storage_bin_dockdoor_master
WHERE wh_id = 123
  AND GREATEST(dockdoor_updated_at, bin_updated_at) >= now() - INTERVAL 30 DAY
ORDER BY last_change DESC
LIMIT 50;
```

### 9. Dock Door Efficiency Metrics
```sql
SELECT 
    usage,
    COUNT(DISTINCT dockdoor_code) as total_doors,
    SUM(max_queue) as total_capacity,
    COUNT(*) as total_bin_assignments,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT dockdoor_code), 2) as avg_bins_per_door,
    ROUND(SUM(max_queue) * 1.0 / COUNT(DISTINCT dockdoor_code), 2) as avg_capacity_per_door,
    COUNT(CASE WHEN multi_trip = true THEN 1 END) as multi_trip_mappings
FROM wms_storage_bin_dockdoor_master
WHERE wh_id = 123
  AND active = true
GROUP BY usage
ORDER BY usage;
```

## Performance Notes
- Optimized for operational queries with composite ordering key
- No partitioning required as this is a mapping dimension table
- Bloom filter indexes enable fast filtering on dock door and bin codes
- Regular updates via ReplacingMergeTree maintain mapping consistency
- Ideal for real-time dock door assignment and routing decisions