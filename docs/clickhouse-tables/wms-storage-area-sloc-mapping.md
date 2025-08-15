# WMS Storage Area SLOC Mapping Table Documentation

## Table: `wms_storage_area_sloc`

### Overview
The WMS Storage Area SLOC Mapping table provides the connection between warehouse storage areas and Storage Location (SLOC) codes for ERP-WMS integration. This table enables inventory visibility management and proper routing of inventory data between ERP and WMS systems.

### Engine & Partitioning
- **Engine**: `ReplacingMergeTree(updatedAt)`
- **Ordering**: `(whId, areaCode, quality, iloc)` - Composite unique key
- **No Partitioning**: Dimension table optimized for JOINs
- **TTL**: Automatically removes deactivated records after 1 minute

## Column Reference

### Core Identifiers
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `id` | String | - | Unique mapping identifier |
| `whId` | Int64 | - | Warehouse identifier |
| `areaCode` | String | - | Storage area code |
| `quality` | String | - | Quality classification |
| `sloc` | String | - | Storage Location (SLOC) code for ERP |
| `iloc` | String | '' | Internal location code |

### SLOC Configuration
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `slocDescription` | String | '' | SLOC description |
| `clientQuality` | String | '' | Client-specific quality classification |
| `inventoryVisible` | Bool | false | Inventory visible in ERP |
| `erpToWMS` | Bool | false | ERP to WMS data flow enabled |

### System Fields
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `deactivatedAt` | Nullable(DateTime64(3)) | NULL | Deactivation timestamp |
| `createdAt` | DateTime64(3) | '1970-01-01 00:00:00' | Creation timestamp |
| `updatedAt` | DateTime64(3) | '1970-01-01 00:00:00' | Last update timestamp |

## TTL Policy
The table automatically removes deactivated records:
```sql
TTL toDateTime(coalesce(deactivatedAt, toDateTime64('2099-12-31 23:59:59', 3))) + INTERVAL 1 MINUTE DELETE 
WHERE deactivatedAt IS NOT NULL
```

## Best Practices

### Filter Active Mappings
Most queries should focus on active mappings:

```sql
-- ✅ GOOD: Filter active mappings only
SELECT areaCode, sloc, slocDescription, inventoryVisible
FROM wms_storage_area_sloc
WHERE whId = 123
  AND deactivatedAt IS NULL;

-- ✅ GOOD: Alternative using current timestamp
SELECT *
FROM wms_storage_area_sloc
WHERE whId = 123
  AND (deactivatedAt IS NULL OR deactivatedAt > now());
```

### ERP Integration Queries
Focus on ERP-visible inventory mappings:

```sql
-- ✅ GOOD: ERP-visible inventory areas
SELECT areaCode, sloc, slocDescription, quality
FROM wms_storage_area_sloc
WHERE whId = 123
  AND inventoryVisible = true
  AND erpToWMS = true
  AND deactivatedAt IS NULL;
```

### Use in JOINs
Ideal for enriching area-based data:

```sql
-- ✅ GOOD: Enrich inventory with SLOC information
SELECT 
    inv.storage_area_code,
    sloc.sloc,
    sloc.slocDescription,
    sloc.inventoryVisible,
    SUM(inv.quantity) as total_quantity
FROM inventory_positions inv
LEFT JOIN wms_storage_area_sloc sloc 
    ON inv.wh_id = sloc.whId 
    AND inv.storage_area_code = sloc.areaCode
    AND sloc.deactivatedAt IS NULL
WHERE inv.wh_id = 123
GROUP BY inv.storage_area_code, sloc.sloc, sloc.slocDescription, sloc.inventoryVisible;
```

## Sample Queries

### 1. Active SLOC Mappings Summary
```sql
SELECT 
    whId,
    COUNT(*) as total_mappings,
    COUNT(CASE WHEN inventoryVisible = true THEN 1 END) as visible_mappings,
    COUNT(CASE WHEN erpToWMS = true THEN 1 END) as erp_enabled_mappings,
    COUNT(DISTINCT areaCode) as unique_areas,
    COUNT(DISTINCT sloc) as unique_slocs,
    COUNT(DISTINCT quality) as unique_qualities
FROM wms_storage_area_sloc
WHERE deactivatedAt IS NULL
GROUP BY whId
ORDER BY total_mappings DESC;
```

### 2. Quality-Based SLOC Distribution
```sql
SELECT 
    quality,
    clientQuality,
    COUNT(*) as mapping_count,
    COUNT(CASE WHEN inventoryVisible = true THEN 1 END) as visible_count,
    COUNT(DISTINCT areaCode) as unique_areas,
    STRING_AGG(DISTINCT sloc, ', ') as sloc_list
FROM wms_storage_area_sloc
WHERE whId = 123
  AND deactivatedAt IS NULL
GROUP BY quality, clientQuality
ORDER BY mapping_count DESC;
```

### 3. ERP Integration Status
```sql
SELECT 
    areaCode,
    sloc,
    slocDescription,
    quality,
    inventoryVisible,
    erpToWMS,
    CASE 
        WHEN inventoryVisible = true AND erpToWMS = true THEN 'Full Integration'
        WHEN inventoryVisible = true AND erpToWMS = false THEN 'Visible Only'
        WHEN inventoryVisible = false AND erpToWMS = true THEN 'Data Flow Only'
        ELSE 'No Integration'
    END as integration_status
FROM wms_storage_area_sloc
WHERE whId = 123
  AND deactivatedAt IS NULL
ORDER BY integration_status, areaCode;
```

### 4. Area Code to SLOC Mapping
```sql
SELECT 
    areaCode,
    COUNT(*) as sloc_mappings,
    STRING_AGG(sloc, ', ') as mapped_slocs,
    STRING_AGG(DISTINCT quality, ', ') as qualities,
    COUNT(CASE WHEN inventoryVisible = true THEN 1 END) as visible_mappings,
    MIN(createdAt) as first_created,
    MAX(updatedAt) as last_updated
FROM wms_storage_area_sloc
WHERE whId = 123
  AND deactivatedAt IS NULL
GROUP BY areaCode
ORDER BY sloc_mappings DESC, areaCode;
```

### 5. SLOC Configuration Analysis
```sql
SELECT 
    sloc,
    slocDescription,
    COUNT(*) as area_mappings,
    COUNT(DISTINCT quality) as quality_variants,
    COUNT(CASE WHEN inventoryVisible = true THEN 1 END) as visible_areas,
    COUNT(CASE WHEN erpToWMS = true THEN 1 END) as erp_enabled_areas,
    STRING_AGG(DISTINCT areaCode, ', ') as mapped_areas
FROM wms_storage_area_sloc
WHERE whId = 123
  AND deactivatedAt IS NULL
GROUP BY sloc, slocDescription
HAVING area_mappings > 1
ORDER BY area_mappings DESC;
```

### 6. Recent Changes Tracking
```sql
SELECT 
    areaCode,
    sloc,
    quality,
    inventoryVisible,
    erpToWMS,
    createdAt,
    updatedAt,
    deactivatedAt,
    CASE 
        WHEN deactivatedAt IS NOT NULL THEN 'Deactivated'
        WHEN updatedAt > createdAt THEN 'Updated'
        ELSE 'Created'
    END as change_type,
    dateDiff('day', COALESCE(updatedAt, createdAt), now()) as days_since_change
FROM wms_storage_area_sloc
WHERE whId = 123
  AND GREATEST(createdAt, updatedAt, COALESCE(deactivatedAt, toDateTime64('1970-01-01', 3))) >= now() - INTERVAL 30 DAY
ORDER BY GREATEST(createdAt, updatedAt, COALESCE(deactivatedAt, toDateTime64('1970-01-01', 3))) DESC;
```

### 7. Inventory Visibility by Area
```sql
SELECT 
    inventoryVisible,
    COUNT(*) as mapping_count,
    COUNT(DISTINCT areaCode) as unique_areas,
    COUNT(DISTINCT sloc) as unique_slocs,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM wms_storage_area_sloc
WHERE whId = 123
  AND deactivatedAt IS NULL
GROUP BY inventoryVisible
ORDER BY inventoryVisible DESC;
```

### 8. Quality and Client Quality Correlation
```sql
SELECT 
    quality,
    clientQuality,
    COUNT(*) as mapping_count,
    COUNT(DISTINCT areaCode) as areas,
    COUNT(DISTINCT sloc) as slocs,
    ROUND(AVG(CASE WHEN inventoryVisible = true THEN 1.0 ELSE 0.0 END), 2) as avg_visibility_rate,
    ROUND(AVG(CASE WHEN erpToWMS = true THEN 1.0 ELSE 0.0 END), 2) as avg_erp_rate
FROM wms_storage_area_sloc
WHERE whId = 123
  AND deactivatedAt IS NULL
  AND quality != ''
GROUP BY quality, clientQuality
ORDER BY quality, clientQuality;
```

### 9. ILOC to SLOC Relationship
```sql
SELECT 
    iloc,
    COUNT(*) as sloc_mappings,
    COUNT(DISTINCT sloc) as unique_slocs,
    COUNT(DISTINCT areaCode) as unique_areas,
    STRING_AGG(DISTINCT quality, ', ') as qualities,
    COUNT(CASE WHEN inventoryVisible = true THEN 1 END) as visible_mappings
FROM wms_storage_area_sloc
WHERE whId = 123
  AND deactivatedAt IS NULL
  AND iloc != ''
GROUP BY iloc
ORDER BY sloc_mappings DESC;
```

## Performance Notes
- Optimized for lookup operations with composite ordering key
- TTL automatically manages deactivated records
- No partitioning required as this is a mapping table
- Ideal for enriching warehouse area data with ERP context
- Use deactivatedAt filters to ensure data consistency