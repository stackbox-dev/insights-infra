# Encarta SKUs Master Table Documentation

## Overview
The `skus_master` table is the comprehensive master data aggregation output of the Encarta SKUs pipeline that combines SKU information with product hierarchy, categorization, brand details, and unit of measure specifications. This table provides the definitive product catalog data for warehouse and supply chain operations.

## Table Details
- **Name**: `skus_master`
- **Topic**: `sbx_uat.encarta.public.skus_master`
- **Primary Key**: `id` - Unique SKU identifier
- **Connector**: `upsert-kafka` with Avro-Confluent format
- **Total Columns**: 107

## Field Categories

### Core Identifiers
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `id` | STRING | No | Unique SKU identifier (PK) |
| `principal_id` | BIGINT | No | Principal/tenant identifier |
| `node_id` | BIGINT | No | Node/warehouse identifier |
| `product_id` | STRING | Yes | Associated product identifier |

### Product Hierarchy
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `category` | STRING | Yes | Product category name |
| `category_group` | STRING | Yes | Category group name |
| `product` | STRING | Yes | Product name |
| `sub_brand` | STRING | Yes | Sub-brand name |
| `brand` | STRING | Yes | Brand name |

### SKU Basic Information
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `code` | STRING | Yes | SKU code |
| `name` | STRING | Yes | SKU name |
| `short_description` | STRING | Yes | Brief description |
| `description` | STRING | Yes | Full description |
| `fulfillment_type` | STRING | Yes | Type of fulfillment (e.g., NORMAL, EXPRESS) |
| `inventory_type` | STRING | Yes | Inventory classification |
| `shelf_life` | INT | Yes | Shelf life in days |
| `avg_l0_per_put` | INT | Yes | Average L0 units per put-away |

### SKU Identifiers
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `identifier1` | STRING | Yes | Primary custom identifier |
| `identifier2` | STRING | Yes | Secondary custom identifier |

### SKU Tags
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `tag1` | STRING | Yes | Custom tag 1 |
| `tag2` | STRING | Yes | Custom tag 2 |
| `tag3` | STRING | Yes | Custom tag 3 |
| `tag4` | STRING | Yes | Custom tag 4 |
| `tag5` | STRING | Yes | Custom tag 5 |
| `tag6` | STRING | Yes | Custom tag 6 |
| `tag7` | STRING | Yes | Custom tag 7 |
| `tag8` | STRING | Yes | Custom tag 8 |
| `tag9` | STRING | Yes | Custom tag 9 |
| `tag10` | STRING | Yes | Custom tag 10 |

### Packaging Configuration
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `handling_unit_type` | STRING | Yes | Type of handling unit |
| `cases_per_layer` | INT | Yes | Number of cases per pallet layer |
| `layers` | INT | Yes | Number of layers on pallet |

### Activity Period
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `active_from` | TIMESTAMP(3) | Yes | Start of active period |
| `active_till` | TIMESTAMP(3) | Yes | End of active period |

### Unit of Measure Hierarchy
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `l0_units` | INT | Yes | Number of L0 (base) units |
| `l1_units` | INT | Yes | Number of L1 units per L0 |
| `l2_units` | INT | Yes | Number of L2 units per L1 |
| `l2_units_final` | INT | Yes | Final L2 units calculation |
| `l3_units` | INT | Yes | Number of L3 units per L2 |
| `l3_units_final` | INT | Yes | Final L3 units calculation |

### L0 (Base Unit) Specifications
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `l0_name` | STRING | Yes | Name of L0 unit (e.g., "Each", "Piece") |
| `l0_weight` | DOUBLE | Yes | Weight of L0 unit (kg) |
| `l0_volume` | DOUBLE | Yes | Volume of L0 unit (m³) |
| `l0_package_type` | STRING | Yes | Package type for L0 |
| `l0_length` | DOUBLE | Yes | Length dimension (cm) |
| `l0_width` | DOUBLE | Yes | Width dimension (cm) |
| `l0_height` | DOUBLE | Yes | Height dimension (cm) |
| `l0_packing_efficiency` | DOUBLE | Yes | Packing efficiency ratio |
| `l0_itf_code` | STRING | Yes | ITF/barcode for L0 |
| `l0_erp_weight` | DOUBLE | Yes | ERP system weight |
| `l0_erp_volume` | DOUBLE | Yes | ERP system volume |
| `l0_erp_length` | DOUBLE | Yes | ERP system length |
| `l0_erp_width` | DOUBLE | Yes | ERP system width |
| `l0_erp_height` | DOUBLE | Yes | ERP system height |
| `l0_text_tag1` | STRING | Yes | L0 custom text tag 1 |
| `l0_text_tag2` | STRING | Yes | L0 custom text tag 2 |
| `l0_image` | STRING | Yes | L0 image URL/path |
| `l0_num_tag1` | DOUBLE | Yes | L0 custom numeric tag 1 |

### L1 Unit Specifications
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `l1_name` | STRING | Yes | Name of L1 unit (e.g., "Inner Pack", "Bundle") |
| `l1_weight` | DOUBLE | Yes | Weight of L1 unit (kg) |
| `l1_volume` | DOUBLE | Yes | Volume of L1 unit (m³) |
| `l1_package_type` | STRING | Yes | Package type for L1 |
| `l1_length` | DOUBLE | Yes | Length dimension (cm) |
| `l1_width` | DOUBLE | Yes | Width dimension (cm) |
| `l1_height` | DOUBLE | Yes | Height dimension (cm) |
| `l1_packing_efficiency` | DOUBLE | Yes | Packing efficiency ratio |
| `l1_itf_code` | STRING | Yes | ITF/barcode for L1 |
| `l1_erp_weight` | DOUBLE | Yes | ERP system weight |
| `l1_erp_volume` | DOUBLE | Yes | ERP system volume |
| `l1_erp_length` | DOUBLE | Yes | ERP system length |
| `l1_erp_width` | DOUBLE | Yes | ERP system width |
| `l1_erp_height` | DOUBLE | Yes | ERP system height |
| `l1_text_tag1` | STRING | Yes | L1 custom text tag 1 |
| `l1_text_tag2` | STRING | Yes | L1 custom text tag 2 |
| `l1_image` | STRING | Yes | L1 image URL/path |
| `l1_num_tag1` | DOUBLE | Yes | L1 custom numeric tag 1 |

### L2 Unit Specifications  
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `l2_name` | STRING | Yes | Name of L2 unit (e.g., "Case", "Box") |
| `l2_weight` | DOUBLE | Yes | Weight of L2 unit (kg) |
| `l2_volume` | DOUBLE | Yes | Volume of L2 unit (m³) |
| `l2_package_type` | STRING | Yes | Package type for L2 |
| `l2_length` | DOUBLE | Yes | Length dimension (cm) |
| `l2_width` | DOUBLE | Yes | Width dimension (cm) |
| `l2_height` | DOUBLE | Yes | Height dimension (cm) |
| `l2_packing_efficiency` | DOUBLE | Yes | Packing efficiency ratio |
| `l2_itf_code` | STRING | Yes | ITF/barcode for L2 |
| `l2_erp_weight` | DOUBLE | Yes | ERP system weight |
| `l2_erp_volume` | DOUBLE | Yes | ERP system volume |
| `l2_erp_length` | DOUBLE | Yes | ERP system length |
| `l2_erp_width` | DOUBLE | Yes | ERP system width |
| `l2_erp_height` | DOUBLE | Yes | ERP system height |
| `l2_text_tag1` | STRING | Yes | L2 custom text tag 1 |
| `l2_text_tag2` | STRING | Yes | L2 custom text tag 2 |
| `l2_image` | STRING | Yes | L2 image URL/path |
| `l2_num_tag1` | DOUBLE | Yes | L2 custom numeric tag 1 |

### L3 Unit Specifications
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `l3_name` | STRING | Yes | Name of L3 unit (e.g., "Pallet", "Master Case") |
| `l3_weight` | DOUBLE | Yes | Weight of L3 unit (kg) |
| `l3_volume` | DOUBLE | Yes | Volume of L3 unit (m³) |
| `l3_package_type` | STRING | Yes | Package type for L3 |
| `l3_length` | DOUBLE | Yes | Length dimension (cm) |
| `l3_width` | DOUBLE | Yes | Width dimension (cm) |
| `l3_height` | DOUBLE | Yes | Height dimension (cm) |
| `l3_packing_efficiency` | DOUBLE | Yes | Packing efficiency ratio |
| `l3_itf_code` | STRING | Yes | ITF/barcode for L3 |
| `l3_erp_weight` | DOUBLE | Yes | ERP system weight |
| `l3_erp_volume` | DOUBLE | Yes | ERP system volume |
| `l3_erp_length` | DOUBLE | Yes | ERP system length |
| `l3_erp_width` | DOUBLE | Yes | ERP system width |
| `l3_erp_height` | DOUBLE | Yes | ERP system height |
| `l3_text_tag1` | STRING | Yes | L3 custom text tag 1 |
| `l3_text_tag2` | STRING | Yes | L3 custom text tag 2 |
| `l3_image` | STRING | Yes | L3 image URL/path |
| `l3_num_tag1` | DOUBLE | Yes | L3 custom numeric tag 1 |

### System Fields
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `active` | BOOLEAN | No | Whether SKU is currently active |
| `classifications` | STRING | No | SKU classifications (JSON) |
| `product_classifications` | STRING | No | Product-level classifications (JSON) |
| `is_deleted` | BOOLEAN | No | Soft delete flag |
| `is_snapshot` | BOOLEAN | No | Whether record is a snapshot |
| `created_at` | TIMESTAMP(3) | No | Record creation timestamp |
| `updated_at` | TIMESTAMP(3) | No | Last update timestamp |

## Data Quality Notes

### Nullability
- Core identifiers (`id`, `principal_id`, `node_id`) and system fields are non-nullable
- Most business fields are nullable to accommodate partial data
- Boolean system fields default to false when not specified

### Data Aggregation Logic
- Combines data from 8 source tables through LEFT JOINs
- Hierarchy: SKUs → Products → Sub-Categories → Categories → Category Groups
- Brand hierarchy: Products → Sub-Brands → Brands
- UOM data aggregated from dedicated UOM tables

### Filtering Rules
- Only includes active, non-deleted records from all source tables
- Uses `COALESCE(is_deleted, FALSE) = FALSE` to handle nulls as non-deleted
- Filters apply at each join level to ensure data quality

## Pipeline Dependencies

### Source Tables
1. `skus` - Core SKU data
2. `products` - Product master data
3. `categories` - Category definitions
4. `sub_categories` - Sub-category definitions
5. `category_groups` - Category group definitions
6. `brands` - Brand master data
7. `sub_brands` - Sub-brand definitions
8. `skus_uom` - Unit of measure specifications

### Join Strategy
- Primary path: SKU → Product → Sub-Category → Category → Category Group
- Secondary path: Product → Sub-Brand → Brand
- UOM enrichment: Direct join on SKU ID

### Performance Characteristics
- Upsert-kafka connector for exactly-once semantics
- Avro-Confluent serialization with Schema Registry
- Optimized for read-heavy analytics workloads

## Usage Patterns

### Analytics Queries
- Product catalog analysis by category/brand hierarchy
- Packaging optimization using UOM specifications
- Inventory planning with shelf life and fulfillment type
- Volume/weight calculations for logistics

### Key Relationships
- One SKU belongs to one Product
- Products organized in hierarchical category structure
- Multiple UOM levels (L0-L3) for flexible unit handling
- Tags enable custom classification schemes

## Unit of Measure (UOM) Hierarchy

### Level Definitions
- **L0**: Base selling unit (Each, Piece, Unit)
- **L1**: Inner pack or bundle (Multi-pack, Bundle)
- **L2**: Case or box (Standard shipping unit)
- **L3**: Pallet or master case (Warehouse storage unit)

### Conversion Logic
- L1 = L0 × `l1_units`
- L2 = L1 × `l2_units` = L0 × `l1_units` × `l2_units`
- L3 = L2 × `l3_units` = L0 × `l1_units` × `l2_units` × `l3_units`

### Dimension Standards
- Length, Width, Height: Centimeters (cm)
- Weight: Kilograms (kg)
- Volume: Cubic meters (m³)
- Packing Efficiency: Ratio (0.0 - 1.0)

---

## Addendum: SKUs Override Table

The `skus_overrides` table provides node-specific (warehouse-specific) overrides for SKU master data. This allows for location-specific customizations while maintaining global master data integrity.

### Table Details
- **Name**: `skus_overrides`
- **Topic**: `sbx_uat.encarta.public.skus_overrides`
- **Primary Key**: `(sku_id, node_id)` - Composite key for SKU-node combination
- **Connector**: `upsert-kafka` with Avro-Confluent format

### Override-Specific Fields

The override table contains the same fields as `skus_master` with these key differences:

#### Additional Key Field
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `sku_id` | STRING | No | SKU identifier (part of composite PK) |
| `node_id` | BIGINT | No | Node/warehouse identifier (part of composite PK) |

### Override Logic

The system applies a three-level priority hierarchy:
1. **Node-specific SKU overrides** (highest priority)
2. **Product-level node overrides** (medium priority)
3. **Master data** (default/fallback)

### Common Override Scenarios

#### Location-Specific Attributes
- Different packaging configurations per warehouse
- Regional shelf life variations
- Local fulfillment type assignments
- Warehouse-specific handling unit types

#### Operational Overrides
- Temporary active/inactive status changes
- Location-specific inventory types
- Custom tag assignments for local operations
- Regional classification adjustments

### Integration with Master Data

When querying SKU data for a specific node:
```sql
SELECT 
    COALESCE(override.field, master.field) AS field
FROM skus_master master
LEFT JOIN skus_overrides override 
    ON master.id = override.sku_id 
    AND override.node_id = :target_node_id
```

### Data Governance

#### Override Validation Rules
- Override records must reference valid SKU IDs
- Node IDs must correspond to active warehouse locations
- System maintains audit trail via `updated_at` timestamp
- Soft deletes (`is_deleted`) cascade from master to overrides

#### Synchronization
- Override records automatically invalidated when master SKU is deleted
- Changes to master data do not overwrite existing overrides
- Override removal reverts to master data values

### Performance Considerations
- Composite primary key enables efficient node-specific lookups
- Partitioning by node_id optimizes warehouse-specific queries
- Sparse table - only contains actual overrides, not full SKU set per node

## Best Practices

### When to Use Overrides
✅ **Appropriate Use Cases:**
- Warehouse-specific packaging variations
- Regional compliance requirements
- Temporary operational adjustments
- Location-based fulfillment strategies

❌ **Avoid Overrides For:**
- Core product attributes (name, brand, category)
- Global identifiers (SKU code, product ID)
- System-wide classifications
- Master data corrections (update master instead)

### Maintenance Guidelines
1. Regular audit of override necessity
2. Document business justification for overrides
3. Implement approval workflow for override creation
4. Schedule periodic override cleanup reviews
5. Monitor override-to-master data drift

### Query Optimization
For efficient override queries:
```sql
-- Use node_id in WHERE clause for partition pruning
WHERE node_id = :warehouse_id 
    AND sku_id IN (...)

-- Leverage composite index
ORDER BY sku_id, node_id

-- Minimize full table scans
LIMIT override queries to specific nodes/SKUs
```