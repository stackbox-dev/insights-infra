# WMS Storage Bin Master Table Documentation

## Table: `wms_storage_bin_master`

### Overview
The WMS Storage Bin Master table provides a comprehensive denormalized view of storage bins with complete information about bin types, zones, areas, positions, and mapping configurations. This table serves as a central dimension for all storage-related analytics and enrichment operations.

### Engine & Partitioning
- **Engine**: `ReplacingMergeTree(updated_at)`
- **Ordering**: `(bin_id)` - Globally unique identifier
- **No Partitioning**: Dimension table optimized for JOINs
- **Deduplication**: Uses `deduplicate_merge_projection_mode = 'drop'`

## Column Reference

### Core Bin Identifiers
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `wh_id` | Int64 | - | Warehouse identifier |
| `bin_code` | String | - | Storage bin code (composite key with wh_id) |
| `bin_id` | String | '' | Unique bin identifier (primary ordering) |

### Basic Bin Information
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `bin_description` | String | '' | Bin description |
| `bin_status` | String | '' | Current bin status |
| `bin_hu_id` | String | '' | Handling unit currently in bin |

### Bin Configuration
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `multi_sku` | Bool | false | Bin allows multiple SKUs |
| `multi_batch` | Bool | false | Bin allows multiple batches |
| `picking_position` | Int32 | 0 | Priority for picking operations |
| `putaway_position` | Int32 | 0 | Priority for putaway operations |
| `rank` | Int32 | 0 | General bin ranking |
| `max_sku_count` | Int32 | 0 | Maximum number of SKUs |
| `max_sku_batch_count` | Int32 | 0 | Maximum SKU-batch combinations |

### Physical Location
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `aisle` | String | '' | Aisle identifier |
| `bay` | String | '' | Bay identifier |
| `level` | String | '' | Level/height identifier |
| `position` | String | '' | Position within bay |
| `depth` | String | '' | Depth position |

### Bin Type Details
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `bin_type_id` | String | '' | Bin type identifier |
| `bin_type_code` | String | '' | Bin type code |
| `bin_type_description` | String | '' | Bin type description |
| `max_volume_in_cc` | Float64 | 0 | Maximum volume in cubic cm |
| `max_weight_in_kg` | Float64 | 0 | Maximum weight in kg |
| `pallet_capacity` | Int32 | 0 | Pallet capacity |
| `storage_hu_type` | String | '' | Handling unit type for storage |
| `auxiliary_bin` | Bool | false | Is auxiliary bin |
| `hu_multi_sku` | Bool | false | HU allows multiple SKUs |
| `hu_multi_batch` | Bool | false | HU allows multiple batches |
| `use_derived_pallet_best_fit` | Bool | false | Use derived pallet fitting |
| `only_full_pallet` | Bool | false | Only full pallet allowed |
| `bin_type_active` | Bool | false | Bin type active status |

### Zone Information
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `zone_id` | String | '' | Zone identifier |
| `zone_code` | String | '' | Zone code |
| `zone_description` | String | '' | Zone description |
| `zone_face` | String | '' | Zone face orientation |
| `peripheral` | Bool | false | Is peripheral zone |
| `surveillance_config` | String | '{}' | Surveillance configuration (JSON) |
| `zone_active` | Bool | false | Zone active status |

### Area Information
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `area_id` | String | '' | Area identifier |
| `area_code` | String | '' | Area code |
| `area_description` | String | '' | Area description |
| `area_type` | String | '' | Area type |
| `rolling_days` | Int32 | 0 | Rolling days configuration |
| `area_active` | Bool | false | Area active status |

### Position Coordinates
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `x1`, `x2` | Float64 | 0 | X-axis coordinates |
| `y1`, `y2` | Float64 | 0 | Y-axis coordinates |
| `position_active` | Bool | false | Position active status |

### Additional Configuration
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `attrs` | String | '{}' | Additional attributes (JSON) |
| `bin_mapping` | String | 'DYNAMIC' | Bin mapping type (FIXED/DYNAMIC) |

### Timestamp Fields
Each source entity has its own timestamp fields:
- `bin_created_at`, `bin_updated_at` - Bin timestamps
- `bin_type_created_at`, `bin_type_updated_at` - Bin type timestamps  
- `zone_created_at`, `zone_updated_at` - Zone timestamps
- `area_created_at`, `area_updated_at` - Area timestamps
- `position_created_at`, `position_updated_at` - Position timestamps
- `mapping_created_at`, `mapping_updated_at` - Mapping timestamps

### Aggregated Metadata
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `created_at` | DateTime64(3) | '1970-01-01 00:00:00' | Overall creation timestamp |
| `updated_at` | DateTime64(3) | '1970-01-01 00:00:00' | Latest update timestamp |

## Indexes
The table includes indexes for optimal JOIN performance:
- **MinMax index**: `wh_id` 
- **Bloom filter indexes**: `bin_code`, `zone_code`, `area_code`

## Best Practices

### Use for Enrichment JOINs
This table is optimized for enrichment operations:

```sql
-- ✅ GOOD: Direct JOIN on bin_id for enrichment
SELECT 
    events.event_id,
    events.bin_id,
    bins.bin_code,
    bins.zone_code,
    bins.area_code,
    bins.bin_type_code
FROM workstation_events events
JOIN wms_storage_bin_master bins ON events.bin_id = bins.bin_id
WHERE events.event_timestamp >= '2024-01-01';
```

### Filter by Active Status
Consider filtering by active status fields:
```sql
-- Filter by active components
SELECT *
FROM wms_storage_bin_master
WHERE bin_type_active = true
  AND zone_active = true
  AND area_active = true;
```

### Warehouse-Specific Queries
Always consider warehouse context:
```sql
-- ✅ GOOD: Include warehouse filter
SELECT zone_code, area_code, COUNT(*) as bin_count
FROM wms_storage_bin_master
WHERE wh_id = 123
GROUP BY zone_code, area_code;
```

## Sample Queries

### 1. Storage Capacity Analysis by Zone
```sql
SELECT 
    zone_code,
    zone_description,
    area_code,
    COUNT(*) as total_bins,
    SUM(max_volume_in_cc) as total_volume_cc,
    SUM(max_weight_in_kg) as total_weight_kg,
    SUM(pallet_capacity) as total_pallet_capacity,
    AVG(max_volume_in_cc) as avg_bin_volume
FROM wms_storage_bin_master
WHERE wh_id = 123
  AND bin_type_active = true
  AND zone_active = true
GROUP BY zone_code, zone_description, area_code
ORDER BY total_volume_cc DESC;
```

### 2. Bin Type Distribution
```sql
SELECT 
    bin_type_code,
    bin_type_description,
    COUNT(*) as bin_count,
    AVG(max_volume_in_cc) as avg_volume,
    AVG(max_weight_in_kg) as avg_weight,
    COUNT(CASE WHEN multi_sku = true THEN 1 END) as multi_sku_bins,
    COUNT(CASE WHEN multi_batch = true THEN 1 END) as multi_batch_bins
FROM wms_storage_bin_master
WHERE wh_id = 123
  AND bin_type_active = true
GROUP BY bin_type_code, bin_type_description
ORDER BY bin_count DESC;
```

### 3. Physical Layout Analysis
```sql
SELECT 
    aisle,
    bay,
    level,
    COUNT(*) as bin_count,
    COUNT(DISTINCT zone_code) as zones_in_location,
    STRING_AGG(DISTINCT zone_code, ', ') as zone_list
FROM wms_storage_bin_master
WHERE wh_id = 123
  AND aisle != ''
  AND bay != ''
  AND level != ''
GROUP BY aisle, bay, level
ORDER BY aisle, bay, level;
```

### 4. Bin Configuration Summary
```sql
SELECT 
    bin_mapping,
    COUNT(*) as bin_count,
    COUNT(CASE WHEN multi_sku = true THEN 1 END) as multi_sku_count,
    COUNT(CASE WHEN multi_batch = true THEN 1 END) as multi_batch_count,
    COUNT(CASE WHEN auxiliary_bin = true THEN 1 END) as auxiliary_count,
    AVG(max_sku_count) as avg_max_sku_count,
    AVG(rank) as avg_rank
FROM wms_storage_bin_master
WHERE wh_id = 123
GROUP BY bin_mapping
ORDER BY bin_count DESC;
```

### 5. Zone Utilization Potential
```sql
SELECT 
    z.zone_code,
    z.zone_description,
    COUNT(*) as total_bins,
    SUM(CASE WHEN b.bin_hu_id != '' THEN 1 ELSE 0 END) as occupied_bins,
    ROUND(SUM(CASE WHEN b.bin_hu_id != '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as occupancy_rate,
    SUM(b.max_volume_in_cc) as total_volume_capacity,
    AVG(b.picking_position) as avg_picking_position,
    AVG(b.putaway_position) as avg_putaway_position
FROM wms_storage_bin_master b
WHERE b.wh_id = 123
  AND b.zone_active = true
GROUP BY zone_code, zone_description
ORDER BY occupancy_rate DESC;
```

### 6. Bin Capacity Analysis by Area Type
```sql
SELECT 
    area_type,
    area_code,
    COUNT(*) as bin_count,
    MIN(max_volume_in_cc) as min_volume,
    MAX(max_volume_in_cc) as max_volume,
    AVG(max_volume_in_cc) as avg_volume,
    MIN(max_weight_in_kg) as min_weight,
    MAX(max_weight_in_kg) as max_weight,
    AVG(max_weight_in_kg) as avg_weight
FROM wms_storage_bin_master
WHERE wh_id = 123
  AND area_type != ''
  AND max_volume_in_cc > 0
GROUP BY area_type, area_code
ORDER BY area_type, avg_volume DESC;
```

### 7. Bin Coordinate Mapping
```sql
SELECT 
    aisle,
    MIN(x1) as min_x,
    MAX(x2) as max_x,
    MIN(y1) as min_y,
    MAX(y2) as max_y,
    COUNT(*) as bin_count,
    AVG((x2 - x1) * (y2 - y1)) as avg_area
FROM wms_storage_bin_master
WHERE wh_id = 123
  AND x1 > 0 AND x2 > 0 AND y1 > 0 AND y2 > 0
  AND position_active = true
GROUP BY aisle
HAVING bin_count >= 10
ORDER BY aisle;
```

### 8. Multi-SKU and Multi-Batch Capability
```sql
SELECT 
    zone_code,
    bin_type_code,
    COUNT(*) as total_bins,
    COUNT(CASE WHEN multi_sku = true THEN 1 END) as multi_sku_bins,
    COUNT(CASE WHEN multi_batch = true THEN 1 END) as multi_batch_bins,
    COUNT(CASE WHEN multi_sku = true AND multi_batch = true THEN 1 END) as flexible_bins,
    ROUND(COUNT(CASE WHEN multi_sku = true THEN 1 END) * 100.0 / COUNT(*), 2) as multi_sku_percentage
FROM wms_storage_bin_master
WHERE wh_id = 123
  AND zone_active = true
  AND bin_type_active = true
GROUP BY zone_code, bin_type_code
HAVING total_bins >= 5
ORDER BY zone_code, multi_sku_percentage DESC;
```

## Performance Notes
- Optimized for enrichment JOINs with ORDER BY (bin_id)
- No partitioning as this is a dimension table
- Bloom filter indexes on key string columns for fast filtering
- Denormalized structure eliminates need for multiple JOINs
- Regularly updated via ReplacingMergeTree for data consistency