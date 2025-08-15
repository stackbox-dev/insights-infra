# Encarta SKU Combined View Documentation

## View: `encarta_skus_combined`

### Overview
The Encarta SKU Combined View is a parameterized ClickHouse view that merges SKU master data with node-specific overrides. It provides a unified interface to access SKU information with warehouse-specific customizations while maintaining data consistency.

### View Structure
- **Type**: Parameterized View (requires `node_id` parameter)
- **Source Tables**: `encarta_skus_master` LEFT JOIN `encarta_skus_overrides`
- **Parameter**: `{node_id:Int64}` - Warehouse/node identifier

## Column Reference

### Core Identifiers
| Column | Type | Description | Source Priority |
|--------|------|-------------|-----------------|
| `sku_id` | String | Unique SKU identifier | Master |
| `node_id` | Int64 | Warehouse/node ID (parameter) | Parameter |
| `principal_id` | Int64 | Principal/tenant ID | Master (never overridden) |
| `code` | String | SKU code | Master (never overridden) |

### Product Hierarchy (Never Overridden)
| Column | Type | Description |
|--------|------|-------------|
| `category` | String | Product category |
| `product` | String | Product name |
| `product_id` | String | Product identifier |
| `category_group` | String | Category group |
| `sub_brand` | String | Sub-brand |
| `brand` | String | Brand name |

### Basic Information (Override Pattern)
| Column | Type | Description | Override Logic |
|--------|------|-------------|----------------|
| `name` | String | SKU name | `if(so.name != '', so.name, sm.name)` |
| `short_description` | String | Short description | `if(so.short_description != '', so.short_description, sm.short_description)` |
| `description` | String | Full description | `if(so.description != '', so.description, sm.description)` |
| `fulfillment_type` | String | Fulfillment type | String override pattern |
| `inventory_type` | String | Inventory type | String override pattern |
| `shelf_life` | Int32 | Shelf life in days | `if(so.shelf_life != 0, so.shelf_life, sm.shelf_life)` |

### SKU Identifiers & Tags (Override Pattern)
| Column | Type | Description |
|--------|------|-------------|
| `identifier1`, `identifier2` | String | Custom identifiers |
| `tag1` through `tag10` | String | Custom tags |

### Packaging Configuration
| Column | Type | Description | Override Logic |
|--------|------|-------------|----------------|
| `handling_unit_type` | String | Handling unit type | String override |
| `cases_per_layer` | Int32 | Cases per layer | Numeric override |
| `layers` | Int32 | Number of layers | Numeric override |
| `avg_l0_per_put` | Int32 | Average L0 units per putaway | Numeric override |

### UOM Hierarchy (L0-L3)
Each level contains the following columns with override patterns:
- `l{X}_name` - UOM level name
- `l{X}_units` - Units at this level
- `l{X}_weight` - Weight per unit (Float64)
- `l{X}_volume` - Volume per unit (Float64)
- `l{X}_package_type` - Package type
- `l{X}_length/width/height` - Dimensions (Float64)
- `l{X}_packing_efficiency` - Packing efficiency (Float64)
- `l{X}_itf_code` - ITF code
- `l{X}_erp_*` - ERP-specific measurements
- `l{X}_text_tag1/2` - Text tags
- `l{X}_image` - Image reference
- `l{X}_num_tag1` - Numeric tag

### Activity Period
| Column | Type | Description | Override Logic |
|--------|------|-------------|----------------|
| `active_from` | DateTime64(3) | Active from date | Timestamp override |
| `active_till` | DateTime64(3) | Active till date | Timestamp override |
| `active` | Bool | Current active status | Boolean override |

### Classifications (JSON Merge)
| Column | Type | Description | Merge Logic |
|--------|------|-------------|-------------|
| `classifications` | String | SKU classifications (JSON) | `JSONMergePatch` override properties overwrite master |
| `product_classifications` | String | Product classifications (JSON) | `JSONMergePatch` override properties overwrite master |
| `combined_classification` | String | Combined classification (JSON) | `JSONMergePatch` override properties overwrite master |

### Metadata
| Column | Type | Description |
|--------|------|-------------|
| `has_override` | Bool | Indicates if override exists for this node |
| `updated_at` | DateTime64(3) | Latest update timestamp from either table |

## Override Logic Patterns

### String Fields
```sql
if(override_field != '', override_field, master_field)
```

### Numeric Fields  
```sql
if(override_field != 0, override_field, master_field)
```

### JSON Fields
```sql
JSONExtractRaw(JSONMergePatch(
    if(master_field = '', '{}', master_field),
    if(override_field = '', '{}', override_field)
))
```

### Boolean Fields
```sql
if(override_field != false, override_field, master_field)
```

### Timestamp Fields
```sql
if(override_field != toDateTime64('1970-01-01 00:00:00', 3), override_field, master_field)
```

## Usage Examples

### Basic Parameterized View Usage
```sql
-- Get all SKUs for warehouse 123
SELECT * FROM encarta_skus_combined(node_id = 123) WHERE active = true;

-- Get specific SKU for warehouse 456
SELECT * FROM encarta_skus_combined(node_id = 456) WHERE sku_id = 'SKU001';
```

## Best Practices

### Always Use node_id Parameter
```sql
-- ✅ GOOD: Parameterized view with node_id
SELECT sku_code, name, category, brand
FROM encarta_skus_combined(node_id = 123)
WHERE category = 'Electronics'
  AND active = true;

-- ❌ BAD: Missing node_id parameter - will cause error
SELECT sku_code, name FROM encarta_skus_combined WHERE active = true;
```

### Filter by Active Status
```sql
-- ✅ GOOD: Filter active SKUs only
SELECT sku_id, code, name, has_override
FROM encarta_skus_combined(node_id = 123)
WHERE active = true;
```

### Use in JOIN Operations
```sql
-- ✅ GOOD: Use in JOINs for enrichment
SELECT 
    inv.sku_id,
    sku.code,
    sku.name,
    sku.category,
    inv.quantity
FROM inventory_events inv
JOIN encarta_skus_combined(node_id = inv.wh_id) sku ON inv.sku_id = sku.sku_id
WHERE inv.event_time >= '2024-01-01'
  AND sku.active = true;
```

## Sample Queries

### 1. SKUs with Overrides by Category
```sql
SELECT 
    category,
    brand,
    COUNT(*) as total_skus,
    COUNT(CASE WHEN has_override = true THEN 1 END) as skus_with_overrides,
    ROUND(COUNT(CASE WHEN has_override = true THEN 1 END) * 100.0 / COUNT(*), 2) as override_percentage
FROM encarta_skus_combined(node_id = 123)
WHERE active = true
GROUP BY category, brand
ORDER BY override_percentage DESC;
```

### 2. SKU Dimensions Analysis
```sql
SELECT 
    category,
    AVG(l0_weight) as avg_weight_l0,
    AVG(l0_volume) as avg_volume_l0,
    AVG(l0_length * l0_width * l0_height) as avg_calculated_volume,
    COUNT(*) as sku_count
FROM encarta_skus_combined(node_id = 123)
WHERE active = true
  AND l0_weight > 0
  AND l0_volume > 0
GROUP BY category
ORDER BY avg_weight_l0 DESC;
```

### 3. UOM Hierarchy Analysis
```sql
SELECT 
    brand,
    category,
    AVG(l0_units) as avg_l0_units,
    AVG(l1_units) as avg_l1_units,
    AVG(l2_units) as avg_l2_units,
    AVG(l3_units) as avg_l3_units,
    COUNT(*) as sku_count
FROM encarta_skus_combined(node_id = 123)
WHERE active = true
  AND l0_units > 0
GROUP BY brand, category
HAVING sku_count >= 10
ORDER BY brand, category;
```

### 4. Packaging Configuration Summary
```sql
SELECT 
    handling_unit_type,
    AVG(cases_per_layer) as avg_cases_per_layer,
    AVG(layers) as avg_layers,
    AVG(cases_per_layer * layers) as avg_cases_per_pallet,
    COUNT(*) as sku_count
FROM encarta_skus_combined(node_id = 123)
WHERE active = true
  AND handling_unit_type != ''
  AND cases_per_layer > 0
  AND layers > 0
GROUP BY handling_unit_type
ORDER BY sku_count DESC;
```

### 5. Classification Analysis
```sql
SELECT 
    category,
    JSONExtractString(combined_classification, 'abc_class') as abc_class,
    JSONExtractString(combined_classification, 'xyz_class') as xyz_class,
    COUNT(*) as sku_count,
    COUNT(CASE WHEN has_override = true THEN 1 END) as with_overrides
FROM encarta_skus_combined(node_id = 123)
WHERE active = true
  AND combined_classification != ''
GROUP BY category, abc_class, xyz_class
ORDER BY category, abc_class, xyz_class;
```

### 6. Recently Updated SKUs
```sql
SELECT 
    sku_id,
    code,
    name,
    category,
    brand,
    has_override,
    updated_at
FROM encarta_skus_combined(node_id = 123)
WHERE updated_at >= now() - INTERVAL 7 DAY
  AND active = true
ORDER BY updated_at DESC
LIMIT 50;
```

## Performance Notes
- Always use the `node_id` parameter - it's required
- The view automatically handles LEFT JOIN with override table
- Active status filtering is recommended for most queries
- JSON functions on classification fields may impact performance on large datasets
- Consider filtering by category/brand before complex aggregations