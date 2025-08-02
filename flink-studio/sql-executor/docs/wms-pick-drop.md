# WMS Pick Drop Summary Table Documentation

## Overview
The `pick_drop_summary` table is the enriched output of the WMS Pick Drop pipeline that combines pick items, drop items, and various dimension enrichments. This table provides comprehensive analytics data for warehouse pick-and-drop operations.

## Table Details
- **Name**: `pick_drop_summary`
- **Topic**: `sbx_uat.wms.public.pick_drop_summary`
- **Primary Key**: `(pick_item_id, drop_item_id)` - Composite key ensuring uniqueness
- **Connector**: `upsert-kafka` with Avro-Confluent format
- **Total Columns**: 217

## Field Categories

### Core Identifiers
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `wh_id` | BIGINT | No | Warehouse identifier |
| `principal_id` | BIGINT | Yes | Principal/tenant identifier (enriched from SKU data) |
| `pick_item_id` | STRING | No | Unique identifier for pick item (PK) |
| `drop_item_id` | STRING | No | Unique identifier for drop item (PK) |

### Warehouse Operations Context
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `session_id` | STRING | Yes | Session identifier for the operation |
| `task_id` | STRING | Yes | Task identifier associated with the operation |
| `lm_trip_id` | STRING | Yes | Last mile trip identifier |
| `mapping_id` | STRING | Yes | Pick-drop mapping identifier |
| `mapping_created_at` | TIMESTAMP(3) | Yes | When the pick-drop mapping was created |

### Pick Item Details

#### Basic Pick Information
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `picked_bin` | STRING | Yes | Code of the bin where item was picked from |
| `picked_sku_id` | STRING | Yes | SKU identifier of the picked item |
| `picked_batch` | STRING | Yes | Batch number of the picked item |
| `picked_uom` | STRING | Yes | Unit of measure for the picked item |
| `overall_qty` | INT | Yes | Overall quantity in the pick operation |
| `qty` | INT | Yes | Specific quantity picked |
| `picked_qty` | INT | Yes | Actual quantity that was picked |

#### Pick Timing
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `pick_item_created_at` | TIMESTAMP(3) | Yes | When the pick item was created |
| `picked_at` | TIMESTAMP(3) | Yes | When the item was actually picked |
| `moved_at` | TIMESTAMP(3) | Yes | When the item was moved |
| `processed_at` | TIMESTAMP(3) | Yes | When the pick was processed |
| `pick_item_updated_at` | TIMESTAMP(3) | Yes | Last update timestamp for pick item |
| `picked_bin_assigned_at` | TIMESTAMP(3) | Yes | When the pick bin was assigned |

#### Pick Worker and Location
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `picked_by_worker_id` | STRING | Yes | ID of worker who performed the pick |
| `moved_by` | STRING | Yes | ID of worker who moved the item |
| `pick_deactivated_by` | STRING | Yes | Who deactivated the pick item |
| `pick_deactivated_at` | TIMESTAMP(3) | Yes | When pick item was deactivated |

#### Handling Units (Pick)
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `hu_code` | STRING | Yes | Handling unit code |
| `hu_kind` | STRING | Yes | Type/kind of handling unit |
| `picked_hu_eq_uom` | STRING | Yes | HU equivalent unit of measure |
| `picked_has_inner_hus` | BOOLEAN | Yes | Whether pick has inner handling units |
| `picked_inner_hu_eq_uom` | STRING | Yes | Inner HU equivalent unit of measure |
| `picked_inner_hu_code` | STRING | Yes | Inner handling unit code |
| `picked_inner_hu_kind_code` | STRING | Yes | Inner handling unit kind code |
| `picked_hu_code` | STRING | Yes | Code of the picked handling unit |

#### Pick Process Control
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `pick_auto_complete` | BOOLEAN | Yes | Whether pick was auto-completed |
| `pick_hu` | BOOLEAN | Yes | Whether this is a handling unit pick |
| `short_allocation_reason` | STRING | Yes | Reason for short allocation if applicable |
| `eligible_drop_locations` | STRING | Yes | Available drop locations for this pick |

### Drop Item Details

#### Basic Drop Information
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `dropped_sku_id` | STRING | Yes | SKU identifier of the dropped item |
| `dropped_batch` | STRING | Yes | Batch number of the dropped item |
| `dropped_uom` | STRING | Yes | Unit of measure for the dropped item |
| `dropped_qty` | INT | Yes | Quantity that was dropped |
| `dropped_bin_code` | STRING | Yes | Code of the bin where item was dropped |
| `drop_bucket` | STRING | Yes | Bucket classification for the drop |

#### Drop Timing
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `dropped_at` | TIMESTAMP(3) | Yes | When the item was actually dropped |
| `drop_item_updated_at` | TIMESTAMP(3) | Yes | Last update timestamp for drop item |
| `drop_created_at` | TIMESTAMP(3) | Yes | When the drop item was created |
| `dest_bin_assigned_at` | TIMESTAMP(3) | Yes | When destination bin was assigned |
| `processed_for_loading_at` | TIMESTAMP(3) | Yes | When processed for loading |
| `processed_on_drop_at` | TIMESTAMP(3) | Yes | When processed on drop |
| `processed_for_pick_at` | TIMESTAMP(3) | Yes | When processed for pick |

#### Drop Worker and Control
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `dropped_by_worker_id` | STRING | Yes | ID of worker who performed the drop |
| `drop_deactivated_by` | STRING | Yes | Who deactivated the drop item |
| `drop_deactivated_at` | TIMESTAMP(3) | Yes | When drop item was deactivated |

#### Handling Units (Drop)
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `dropped_hu_eq_uom` | STRING | Yes | Dropped HU equivalent unit of measure |
| `dropped_has_inner_hus` | BOOLEAN | Yes | Whether drop has inner handling units |
| `dropped_inner_hu_id` | STRING | Yes | Inner handling unit identifier |
| `dropped_inner_hu_eq_uom` | STRING | Yes | Inner HU equivalent unit of measure |
| `drop_inner_hu_code` | STRING | Yes | Inner handling unit code for drop |
| `dropped_inner_hu_kind_code` | STRING | Yes | Inner handling unit kind code |

#### Drop Process Control
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `drop_auto_complete` | BOOLEAN | Yes | Whether drop was auto-completed |
| `drop_hu_in_bin` | BOOLEAN | Yes | Whether HU is placed in bin |
| `scan_dest_hu` | BOOLEAN | Yes | Whether destination HU was scanned |
| `allow_hu_break` | BOOLEAN | Yes | Whether HU breaking is allowed |
| `scan_inner_hus` | BOOLEAN | Yes | Whether inner HUs were scanned |
| `drop_inner_hu` | BOOLEAN | Yes | Whether this involves inner HU drop |
| `allow_inner_hu_break` | BOOLEAN | Yes | Whether inner HU breaking is allowed |
| `inner_hu_broken` | BOOLEAN | Yes | Whether inner HU was broken |
| `hu_broken` | BOOLEAN | Yes | Whether HU was broken |
| `allow_hu_break_v2` | BOOLEAN | Yes | Version 2 of HU break allowance |
| `quant_slotting_for_hus` | BOOLEAN | Yes | Whether quantity slotting applies to HUs |

### Task Enrichment
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `task_kind` | STRING | Yes | Type/category of the task |
| `task_code` | STRING | Yes | Task code identifier |
| `task_sequence` | INT | Yes | Sequence number of the task |
| `task_state` | STRING | Yes | Current state of the task |
| `task_attrs` | STRING | Yes | Task attributes (JSON) |
| `task_progress` | STRING | Yes | Task progress information |
| `task_created_at` | TIMESTAMP(3) | Yes | When the task was created |
| `task_updated_at` | TIMESTAMP(3) | Yes | When the task was last updated |
| `task_exclusive` | BOOLEAN | Yes | Whether task is exclusive |
| `task_active` | BOOLEAN | Yes | Whether task is active |
| `task_auto_complete` | BOOLEAN | Yes | Whether task auto-completes |
| `allow_force_complete` | BOOLEAN | Yes | Whether task can be force-completed |
| `force_completed` | BOOLEAN | Yes | Whether task was force-completed |
| `force_complete_task_id` | STRING | Yes | ID of task that force-completed this |
| `task_subkind` | STRING | Yes | Sub-category of the task |
| `label` | STRING | Yes | Task label |
| `wave` | INT | Yes | Wave number for the task |

### Session Enrichment
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `session_kind` | STRING | Yes | Type/category of the session |
| `session_code` | STRING | Yes | Session code identifier |
| `session_attrs` | STRING | Yes | Session attributes (JSON) |
| `session_created_at` | TIMESTAMP(3) | Yes | When the session was created |
| `session_updated_at` | TIMESTAMP(3) | Yes | When the session was last updated |
| `active` | BOOLEAN | Yes | Whether session is active |
| `session_state` | STRING | Yes | Current state of the session |
| `session_progress` | STRING | Yes | Session progress information |
| `session_auto_complete` | BOOLEAN | Yes | Whether session auto-completes |

### Last Mile Trip Enrichment
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `lm_trip_code` | STRING | Yes | Last mile trip code |
| `lm_trip_priority` | INT | Yes | Priority of the trip |
| `lm_dockdoor` | STRING | Yes | Dock door for the trip |
| `lm_vehicle_no` | STRING | Yes | Vehicle number |
| `lm_vehicle_type` | STRING | Yes | Type of vehicle |
| `lm_delivery_date` | DATE | Yes | Scheduled delivery date |
| `lm_session_created_at` | TIMESTAMP(3) | Yes | When LM session was created |
| `lm_trip_created_at` | TIMESTAMP(3) | Yes | When LM trip was created |
| `lm_bb_id` | STRING | Yes | Building block identifier |
| `lm_trip_type` | STRING | Yes | Type of the trip |
| `lm_dockdoor_id` | STRING | Yes | Dock door identifier |
| `lm_vehicle_id` | STRING | Yes | Vehicle identifier |
| `drop_lm_trip_id` | STRING | Yes | Last mile trip ID for drop |

### Worker Enrichment
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `worker_code` | STRING | Yes | Worker code |
| `worker_name` | STRING | Yes | Worker name |
| `worker_phone` | STRING | Yes | Worker phone number |
| `worker_supervisor` | BOOLEAN | Yes | Whether worker is a supervisor |
| `worker_active` | BOOLEAN | Yes | Whether worker is active |

### Handling Unit Enrichment (Dropped)
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `dropped_hu_code` | STRING | Yes | Code of the dropped handling unit |
| `dropped_hu_kind_id` | STRING | Yes | Kind identifier of dropped HU |
| `dropped_hu_session_id` | STRING | Yes | Session ID associated with dropped HU |
| `dropped_hu_task_id` | STRING | Yes | Task ID associated with dropped HU |
| `dropped_hu_storage_id` | STRING | Yes | Storage location of dropped HU |
| `dropped_hu_outer_hu_id` | STRING | Yes | Outer HU identifier |
| `dropped_hu_state` | STRING | Yes | State of the dropped HU |
| `dropped_hu_attrs` | STRING | Yes | Attributes of dropped HU (JSON) |
| `dropped_hu_lock_task_id` | STRING | Yes | Task ID that locked the HU |
| `dropped_hu_effective_storage_id` | STRING | Yes | Effective storage location |
| `dropped_hu_is_deleted` | BOOLEAN | Yes | Whether HU is marked as deleted |
| `dropped_hu_created_at` | TIMESTAMP(3) | Yes | When dropped HU was created |
| `dropped_hu_updated_at` | TIMESTAMP(3) | Yes | When dropped HU was last updated |

### Picked SKU Enrichment (Comprehensive)

#### Basic SKU Information
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `picked_sku_principal_id` | BIGINT | Yes | Principal ID for picked SKU |
| `picked_sku_node_id` | BIGINT | Yes | Node ID for picked SKU |
| `picked_sku_category` | STRING | Yes | Product category |
| `picked_sku_product` | STRING | Yes | Product name |
| `picked_sku_product_id` | STRING | Yes | Product identifier |
| `picked_sku_category_group` | STRING | Yes | Category group |
| `picked_sku_sub_brand` | STRING | Yes | Sub-brand name |
| `picked_sku_brand` | STRING | Yes | Brand name |
| `picked_sku_code` | STRING | Yes | SKU code |
| `picked_sku_name` | STRING | Yes | SKU name |
| `picked_sku_short_description` | STRING | Yes | Short description |
| `picked_sku_description` | STRING | Yes | Full description |
| `picked_sku_fulfillment_type` | STRING | Yes | Type of fulfillment |
| `picked_sku_inventory_type` | STRING | Yes | Inventory classification |
| `picked_sku_shelf_life` | INT | Yes | Shelf life in days |
| `picked_sku_active` | BOOLEAN | Yes | Whether SKU is active |
| `picked_sku_classifications` | STRING | Yes | SKU classifications |
| `picked_sku_product_classifications` | STRING | Yes | Product classifications |

#### SKU Tags and Metadata
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `picked_sku_tag1` | STRING | Yes | Custom tag 1 |
| `picked_sku_tag2` | STRING | Yes | Custom tag 2 |
| `picked_sku_tag3` | STRING | Yes | Custom tag 3 |
| `picked_sku_tag4` | STRING | Yes | Custom tag 4 |
| `picked_sku_tag5` | STRING | Yes | Custom tag 5 |

#### Packaging Information
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `picked_sku_handling_unit_type` | STRING | Yes | Type of handling unit |
| `picked_sku_cases_per_layer` | INT | Yes | Cases per layer in packaging |
| `picked_sku_layers` | INT | Yes | Number of layers |

#### Unit of Measure Hierarchy
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `picked_sku_l0_units` | INT | Yes | L0 (base) units |
| `picked_sku_l1_units` | INT | Yes | L1 units |
| `picked_sku_l2_units` | INT | Yes | L2 units |
| `picked_sku_l3_units` | INT | Yes | L3 units |

#### L0 (Base Unit) Specifications
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `picked_sku_l0_name` | STRING | Yes | Name of L0 unit |
| `picked_sku_l0_weight` | DOUBLE | Yes | Weight of L0 unit |
| `picked_sku_l0_volume` | DOUBLE | Yes | Volume of L0 unit |
| `picked_sku_l0_package_type` | STRING | Yes | Package type for L0 |
| `picked_sku_l0_length` | DOUBLE | Yes | Length dimension |
| `picked_sku_l0_width` | DOUBLE | Yes | Width dimension |
| `picked_sku_l0_height` | DOUBLE | Yes | Height dimension |
| `picked_sku_l0_packing_efficiency` | DOUBLE | Yes | Packing efficiency ratio |

#### L1 Unit Specifications
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `picked_sku_l1_name` | STRING | Yes | Name of L1 unit |
| `picked_sku_l1_weight` | DOUBLE | Yes | Weight of L1 unit |
| `picked_sku_l1_volume` | DOUBLE | Yes | Volume of L1 unit |
| `picked_sku_l1_package_type` | STRING | Yes | Package type for L1 |
| `picked_sku_l1_length` | DOUBLE | Yes | Length dimension |
| `picked_sku_l1_width` | DOUBLE | Yes | Width dimension |
| `picked_sku_l1_height` | DOUBLE | Yes | Height dimension |
| `picked_sku_l1_packing_efficiency` | DOUBLE | Yes | Packing efficiency ratio |

#### L2 Unit Specifications
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `picked_sku_l2_name` | STRING | Yes | Name of L2 unit |
| `picked_sku_l2_weight` | DOUBLE | Yes | Weight of L2 unit |
| `picked_sku_l2_volume` | DOUBLE | Yes | Volume of L2 unit |
| `picked_sku_l2_package_type` | STRING | Yes | Package type for L2 |
| `picked_sku_l2_length` | DOUBLE | Yes | Length dimension |
| `picked_sku_l2_width` | DOUBLE | Yes | Width dimension |
| `picked_sku_l2_height` | DOUBLE | Yes | Height dimension |
| `picked_sku_l2_packing_efficiency` | DOUBLE | Yes | Packing efficiency ratio |

#### L3 Unit Specifications
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `picked_sku_l3_name` | STRING | Yes | Name of L3 unit |
| `picked_sku_l3_weight` | DOUBLE | Yes | Weight of L3 unit |
| `picked_sku_l3_volume` | DOUBLE | Yes | Volume of L3 unit |
| `picked_sku_l3_package_type` | STRING | Yes | Package type for L3 |
| `picked_sku_l3_length` | DOUBLE | Yes | Length dimension |
| `picked_sku_l3_width` | DOUBLE | Yes | Width dimension |
| `picked_sku_l3_height` | DOUBLE | Yes | Height dimension |
| `picked_sku_l3_packing_efficiency` | DOUBLE | Yes | Packing efficiency ratio |

### Dropped SKU Enrichment (Comprehensive)
*Same structure as Picked SKU but with `dropped_sku_` prefix*

The dropped SKU enrichment follows the identical structure as picked SKU enrichment with 62 fields covering:
- Basic SKU information (principal_id, node_id, category, product, etc.)
- SKU tags and metadata (tag1-tag5)
- Packaging information (handling_unit_type, cases_per_layer, layers)
- Unit of measure hierarchy (l0_units through l3_units)
- L0-L3 unit specifications (name, weight, volume, dimensions, packing_efficiency)

### Additional System Fields

#### Location and Navigation
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `destination_bin_code` | STRING | Yes | Destination bin code |
| `original_source_bin_code` | STRING | Yes | Original source bin code |
| `drop_original_source_bin_code` | STRING | Yes | Original source bin for drop |
| `bin_id` | STRING | Yes | Bin identifier |
| `bin_hu_id` | STRING | Yes | Bin handling unit ID |
| `destination_bin_id` | STRING | Yes | Destination bin ID |
| `destination_bin_hu_id` | STRING | Yes | Destination bin HU ID |
| `source_bin_id` | STRING | Yes | Source bin ID |
| `source_bin_hu_id` | STRING | Yes | Source bin HU ID |
| `drop_bin_id` | STRING | Yes | Drop bin ID |
| `drop_bin_hu_id` | STRING | Yes | Drop bin HU ID |
| `original_source_bin_id` | STRING | Yes | Original source bin ID |
| `original_destination_bin_id` | STRING | Yes | Original destination bin ID |
| `iloc` | STRING | Yes | Internal location code |
| `dest_iloc` | STRING | Yes | Destination internal location |
| `drop_iloc` | STRING | Yes | Drop internal location |
| `source_iloc` | STRING | Yes | Source internal location |

#### Handling Unit References
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `scanned_source_hu_id` | STRING | Yes | Scanned source HU ID |
| `picked_source_hu_id` | STRING | Yes | Picked source HU ID |
| `carrier_hu_id` | STRING | Yes | Carrier HU ID |
| `inner_hu_id` | STRING | Yes | Inner HU ID |
| `inner_hu_kind_id` | STRING | Yes | Inner HU kind ID |
| `dest_hu_id` | STRING | Yes | Destination HU ID |
| `input_dest_hu_id` | STRING | Yes | Input destination HU ID |
| `drop_input_dest_hu_id` | STRING | Yes | Drop input destination HU ID |

#### Process Tracking
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `parent_item_id` | STRING | Yes | Parent item identifier |
| `drop_parent_item_id` | STRING | Yes | Drop parent item identifier |
| `old_batch` | STRING | Yes | Previous batch number |
| `dest_bucket` | STRING | Yes | Destination bucket |
| `source_bucket` | STRING | Yes | Source bucket |
| `picked_quant_bucket` | STRING | Yes | Picked quantity bucket |
| `drop_quant_bucket` | STRING | Yes | Drop quantity bucket |
| `pd_previous_task_id` | STRING | Yes | Previous task ID for pick-drop |
| `drop_item_previous_task_id` | STRING | Yes | Previous task ID for drop item |

#### Technical Implementation
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `pick_attrs` | STRING | Yes | Pick attributes (JSON) |
| `drop_attrs` | STRING | Yes | Drop attributes (JSON) |
| `mhe_id` | STRING | Yes | Material handling equipment ID |
| `drop_mhe_id` | STRING | Yes | Drop MHE ID |
| `induction_id` | STRING | Yes | Induction identifier |
| `drop_induction_id` | STRING | Yes | Drop induction identifier |

## Data Quality Notes

### Nullability
- Most fields are nullable (Yes) as they represent enrichment data that may not always be available
- Only primary key fields (`pick_item_id`, `drop_item_id`) and `wh_id` are non-nullable
- Fields marked as "No" in nullable column are required for every record

### SKU Override Priority
- SKU fields use `COALESCE` logic prioritizing node-specific overrides over global master data
- Pattern: `COALESCE(override_value, master_value, default_value)`

### Temporal Join Consistency
- All enrichment data is joined using `FOR SYSTEM_TIME AS OF pick_item_updated_at`
- Ensures point-in-time consistency across all dimension data

## Pipeline Dependencies

### Source Tables
- `pick_drop_basic` - Core pick-drop event data
- `sessions` - Session dimension
- `tasks` - Task dimension  
- `trips` - Trip dimension
- `workers` - Worker dimension
- `handling_units` - Handling unit dimension
- `sku_overrides` - Node-specific SKU overrides
- `sku_masters` - Global SKU master data

### Performance Characteristics
- Upsert-kafka connector with 4 parallel tasks
- Buffer flush: 2000 rows or 5 seconds
- Avro-Confluent serialization with Schema Registry

## Usage Patterns

### Analytics Queries
- Time-series analysis using timestamp fields
- Worker performance analysis via worker enrichment
- SKU movement analysis with comprehensive product data
- Operational efficiency metrics via task/session data

### Key Relationships
- One pick item can relate to multiple drop items
- Each record represents a unique pick-drop pair
- Enrichment provides 360-degree view of warehouse operations

## ClickHouse DDL

When pushing this data to ClickHouse for analytics, use the following table definition:

```sql
CREATE TABLE pick_drop_summary
(
    -- Core Identifiers
    wh_id UInt64,
    principal_id UInt64 DEFAULT 0,
    pick_item_id String,
    drop_item_id String,
    
    -- Warehouse Operations Context
    session_id String DEFAULT '',
    task_id String DEFAULT '',
    lm_trip_id String DEFAULT '',
    mapping_id String DEFAULT '',
    mapping_created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    
    -- Pick Item Details
    picked_bin String DEFAULT '',
    picked_sku_id String DEFAULT '',
    picked_batch String DEFAULT '',
    picked_uom String DEFAULT '',
    overall_qty Int32 DEFAULT 0,
    qty Int32 DEFAULT 0,
    picked_qty Int32 DEFAULT 0,
    hu_code String DEFAULT '',
    destination_bin_code String DEFAULT '',
    pick_item_created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    picked_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    picked_by_worker_id String DEFAULT '',
    moved_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    processed_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    pick_item_updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    picked_bin_assigned_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    picked_hu_eq_uom String DEFAULT '',
    picked_has_inner_hus Bool DEFAULT false,
    picked_inner_hu_eq_uom String DEFAULT '',
    picked_inner_hu_code String DEFAULT '',
    picked_inner_hu_kind_code String DEFAULT '',
    picked_quant_bucket String DEFAULT '',
    pick_auto_complete Bool DEFAULT false,
    pick_hu Bool DEFAULT false,
    short_allocation_reason String DEFAULT '',
    eligible_drop_locations String DEFAULT '',
    moved_by String DEFAULT '',
    pick_deactivated_by String DEFAULT '',
    pick_deactivated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    
    -- Drop Item Details
    dropped_sku_id String DEFAULT '',
    dropped_batch String DEFAULT '',
    dropped_uom String DEFAULT '',
    drop_bucket String DEFAULT '',
    picked_hu_code String DEFAULT '',
    dropped_bin_code String DEFAULT '',
    dropped_qty Int32 DEFAULT 0,
    dropped_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    drop_item_updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    dest_bin_assigned_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    drop_uom String DEFAULT '',
    processed_for_loading_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    processed_on_drop_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    processed_for_pick_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    dropped_by_worker_id String DEFAULT '',
    drop_deactivated_by String DEFAULT '',
    drop_deactivated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    dropped_hu_eq_uom String DEFAULT '',
    dropped_has_inner_hus Bool DEFAULT false,
    dropped_inner_hu_id String DEFAULT '',
    dropped_inner_hu_eq_uom String DEFAULT '',
    drop_inner_hu_code String DEFAULT '',
    dropped_inner_hu_kind_code String DEFAULT '',
    drop_hu_in_bin Bool DEFAULT false,
    scan_dest_hu Bool DEFAULT false,
    allow_hu_break Bool DEFAULT false,
    scan_inner_hus Bool DEFAULT false,
    drop_inner_hu Bool DEFAULT false,
    allow_inner_hu_break Bool DEFAULT false,
    inner_hu_broken Bool DEFAULT false,
    drop_auto_complete Bool DEFAULT false,
    hu_broken Bool DEFAULT false,
    allow_hu_break_v2 Bool DEFAULT false,
    quant_slotting_for_hus Bool DEFAULT false,
    
    -- Task Enrichment
    task_kind String DEFAULT '',
    task_code String DEFAULT '',
    task_sequence Int32 DEFAULT 0,
    task_state String DEFAULT '',
    task_attrs String DEFAULT '',
    task_progress String DEFAULT '',
    task_created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    task_updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    task_exclusive Bool DEFAULT false,
    task_active Bool DEFAULT false,
    task_auto_complete Bool DEFAULT false,
    allow_force_complete Bool DEFAULT false,
    force_completed Bool DEFAULT false,
    force_complete_task_id String DEFAULT '',
    task_subkind String DEFAULT '',
    `label` String DEFAULT '',
    wave Int32 DEFAULT 0,
    
    -- Session Enrichment
    session_kind String DEFAULT '',
    session_code String DEFAULT '',
    session_attrs String DEFAULT '',
    session_created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    session_updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    active Bool DEFAULT false,
    session_state String DEFAULT '',
    session_progress String DEFAULT '',
    session_auto_complete Bool DEFAULT false,
    
    -- Last Mile Trip Enrichment
    lm_trip_code String DEFAULT '',
    lm_trip_priority Int32 DEFAULT 0,
    lm_dockdoor String DEFAULT '',
    lm_vehicle_no String DEFAULT '',
    lm_vehicle_type String DEFAULT '',
    lm_delivery_date Date DEFAULT toDate('1970-01-01'),
    lm_session_created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    lm_trip_created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    lm_bb_id String DEFAULT '',
    lm_trip_type String DEFAULT '',
    lm_dockdoor_id String DEFAULT '',
    lm_vehicle_id String DEFAULT '',
    drop_lm_trip_id String DEFAULT '',
    
    -- Worker Enrichment
    worker_code String DEFAULT '',
    worker_name String DEFAULT '',
    worker_phone String DEFAULT '',
    worker_supervisor Bool DEFAULT false,
    worker_active Bool DEFAULT false,
    
    -- Handling Unit Enrichment (Dropped)
    dropped_hu_code String DEFAULT '',
    dropped_hu_kind_id String DEFAULT '',
    dropped_hu_session_id String DEFAULT '',
    dropped_hu_task_id String DEFAULT '',
    dropped_hu_storage_id String DEFAULT '',
    dropped_hu_outer_hu_id String DEFAULT '',
    dropped_hu_state String DEFAULT '',
    dropped_hu_attrs String DEFAULT '',
    dropped_hu_lock_task_id String DEFAULT '',
    dropped_hu_effective_storage_id String DEFAULT '',
    dropped_hu_is_deleted Bool DEFAULT false,
    dropped_hu_created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    dropped_hu_updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    
    -- Picked SKU Enrichment (Comprehensive)
    picked_sku_principal_id UInt64 DEFAULT 0,
    picked_sku_node_id UInt64 DEFAULT 0,
    picked_sku_category String DEFAULT '',
    picked_sku_product String DEFAULT '',
    picked_sku_product_id String DEFAULT '',
    picked_sku_category_group String DEFAULT '',
    picked_sku_sub_brand String DEFAULT '',
    picked_sku_brand String DEFAULT '',
    picked_sku_code String DEFAULT '',
    picked_sku_name String DEFAULT '',
    picked_sku_short_description String DEFAULT '',
    picked_sku_description String DEFAULT '',
    picked_sku_fulfillment_type String DEFAULT '',
    picked_sku_inventory_type String DEFAULT '',
    picked_sku_shelf_life Int32 DEFAULT 0,
    picked_sku_active Bool DEFAULT false,
    picked_sku_classifications String DEFAULT '',
    picked_sku_product_classifications String DEFAULT '',
    picked_sku_tag1 String DEFAULT '',
    picked_sku_tag2 String DEFAULT '',
    picked_sku_tag3 String DEFAULT '',
    picked_sku_tag4 String DEFAULT '',
    picked_sku_tag5 String DEFAULT '',
    picked_sku_handling_unit_type String DEFAULT '',
    picked_sku_cases_per_layer Int32 DEFAULT 0,
    picked_sku_layers Int32 DEFAULT 0,
    picked_sku_l0_units Int32 DEFAULT 0,
    picked_sku_l1_units Int32 DEFAULT 0,
    picked_sku_l2_units Int32 DEFAULT 0,
    picked_sku_l3_units Int32 DEFAULT 0,
    picked_sku_l0_name String DEFAULT '',
    picked_sku_l0_weight Float64 DEFAULT 0.0,
    picked_sku_l0_volume Float64 DEFAULT 0.0,
    picked_sku_l0_package_type String DEFAULT '',
    picked_sku_l0_length Float64 DEFAULT 0.0,
    picked_sku_l0_width Float64 DEFAULT 0.0,
    picked_sku_l0_height Float64 DEFAULT 0.0,
    picked_sku_l0_packing_efficiency Float64 DEFAULT 0.0,
    picked_sku_l1_name String DEFAULT '',
    picked_sku_l1_weight Float64 DEFAULT 0.0,
    picked_sku_l1_volume Float64 DEFAULT 0.0,
    picked_sku_l1_package_type String DEFAULT '',
    picked_sku_l1_length Float64 DEFAULT 0.0,
    picked_sku_l1_width Float64 DEFAULT 0.0,
    picked_sku_l1_height Float64 DEFAULT 0.0,
    picked_sku_l1_packing_efficiency Float64 DEFAULT 0.0,
    picked_sku_l2_name String DEFAULT '',
    picked_sku_l2_weight Float64 DEFAULT 0.0,
    picked_sku_l2_volume Float64 DEFAULT 0.0,
    picked_sku_l2_package_type String DEFAULT '',
    picked_sku_l2_length Float64 DEFAULT 0.0,
    picked_sku_l2_width Float64 DEFAULT 0.0,
    picked_sku_l2_height Float64 DEFAULT 0.0,
    picked_sku_l2_packing_efficiency Float64 DEFAULT 0.0,
    picked_sku_l3_name String DEFAULT '',
    picked_sku_l3_weight Float64 DEFAULT 0.0,
    picked_sku_l3_volume Float64 DEFAULT 0.0,
    picked_sku_l3_package_type String DEFAULT '',
    picked_sku_l3_length Float64 DEFAULT 0.0,
    picked_sku_l3_width Float64 DEFAULT 0.0,
    picked_sku_l3_height Float64 DEFAULT 0.0,
    picked_sku_l3_packing_efficiency Float64 DEFAULT 0.0,
    
    -- Dropped SKU Enrichment (Comprehensive)
    dropped_sku_principal_id UInt64 DEFAULT 0,
    dropped_sku_node_id UInt64 DEFAULT 0,
    dropped_sku_category String DEFAULT '',
    dropped_sku_product String DEFAULT '',
    dropped_sku_product_id String DEFAULT '',
    dropped_sku_category_group String DEFAULT '',
    dropped_sku_sub_brand String DEFAULT '',
    dropped_sku_brand String DEFAULT '',
    dropped_sku_code String DEFAULT '',
    dropped_sku_name String DEFAULT '',
    dropped_sku_short_description String DEFAULT '',
    dropped_sku_description String DEFAULT '',
    dropped_sku_fulfillment_type String DEFAULT '',
    dropped_sku_inventory_type String DEFAULT '',
    dropped_sku_shelf_life Int32 DEFAULT 0,
    dropped_sku_active Bool DEFAULT false,
    dropped_sku_classifications String DEFAULT '',
    dropped_sku_product_classifications String DEFAULT '',
    dropped_sku_tag1 String DEFAULT '',
    dropped_sku_tag2 String DEFAULT '',
    dropped_sku_tag3 String DEFAULT '',
    dropped_sku_tag4 String DEFAULT '',
    dropped_sku_tag5 String DEFAULT '',
    dropped_sku_handling_unit_type String DEFAULT '',
    dropped_sku_cases_per_layer Int32 DEFAULT 0,
    dropped_sku_layers Int32 DEFAULT 0,
    dropped_sku_l0_units Int32 DEFAULT 0,
    dropped_sku_l1_units Int32 DEFAULT 0,
    dropped_sku_l2_units Int32 DEFAULT 0,
    dropped_sku_l3_units Int32 DEFAULT 0,
    dropped_sku_l0_name String DEFAULT '',
    dropped_sku_l0_weight Float64 DEFAULT 0.0,
    dropped_sku_l0_volume Float64 DEFAULT 0.0,
    dropped_sku_l0_package_type String DEFAULT '',
    dropped_sku_l0_length Float64 DEFAULT 0.0,
    dropped_sku_l0_width Float64 DEFAULT 0.0,
    dropped_sku_l0_height Float64 DEFAULT 0.0,
    dropped_sku_l0_packing_efficiency Float64 DEFAULT 0.0,
    dropped_sku_l1_name String DEFAULT '',
    dropped_sku_l1_weight Float64 DEFAULT 0.0,
    dropped_sku_l1_volume Float64 DEFAULT 0.0,
    dropped_sku_l1_package_type String DEFAULT '',
    dropped_sku_l1_length Float64 DEFAULT 0.0,
    dropped_sku_l1_width Float64 DEFAULT 0.0,
    dropped_sku_l1_height Float64 DEFAULT 0.0,
    dropped_sku_l1_packing_efficiency Float64 DEFAULT 0.0,
    dropped_sku_l2_name String DEFAULT '',
    dropped_sku_l2_weight Float64 DEFAULT 0.0,
    dropped_sku_l2_volume Float64 DEFAULT 0.0,
    dropped_sku_l2_package_type String DEFAULT '',
    dropped_sku_l2_length Float64 DEFAULT 0.0,
    dropped_sku_l2_width Float64 DEFAULT 0.0,
    dropped_sku_l2_height Float64 DEFAULT 0.0,
    dropped_sku_l2_packing_efficiency Float64 DEFAULT 0.0,
    dropped_sku_l3_name String DEFAULT '',
    dropped_sku_l3_weight Float64 DEFAULT 0.0,
    dropped_sku_l3_volume Float64 DEFAULT 0.0,
    dropped_sku_l3_package_type String DEFAULT '',
    dropped_sku_l3_length Float64 DEFAULT 0.0,
    dropped_sku_l3_width Float64 DEFAULT 0.0,
    dropped_sku_l3_height Float64 DEFAULT 0.0,
    dropped_sku_l3_packing_efficiency Float64 DEFAULT 0.0,
    
    -- Additional System Fields
    parent_item_id String DEFAULT '',
    old_batch String DEFAULT '',
    dest_bucket String DEFAULT '',
    original_source_bin_code String DEFAULT '',
    drop_parent_item_id String DEFAULT '',
    drop_original_source_bin_code String DEFAULT '',
    bin_id String DEFAULT '',
    bin_hu_id String DEFAULT '',
    destination_bin_id String DEFAULT '',
    destination_bin_hu_id String DEFAULT '',
    source_bin_id String DEFAULT '',
    source_bin_hu_id String DEFAULT '',
    drop_bin_id String DEFAULT '',
    drop_bin_hu_id String DEFAULT '',
    original_source_bin_id String DEFAULT '',
    original_destination_bin_id String DEFAULT '',
    iloc String DEFAULT '',
    dest_iloc String DEFAULT '',
    drop_iloc String DEFAULT '',
    source_iloc String DEFAULT '',
    scanned_source_hu_id String DEFAULT '',
    picked_source_hu_id String DEFAULT '',
    carrier_hu_id String DEFAULT '',
    inner_hu_id String DEFAULT '',
    inner_hu_kind_id String DEFAULT '',
    dest_hu_id String DEFAULT '',
    input_dest_hu_id String DEFAULT '',
    drop_input_dest_hu_id String DEFAULT '',
    scan_source_hu_kind String DEFAULT '',
    pick_source_hu_kind String DEFAULT '',
    carrier_hu_kind String DEFAULT '',
    scanned_source_hu_code String DEFAULT '',
    picked_source_hu_code String DEFAULT '',
    carrier_hu_code String DEFAULT '',
    hu_kind String DEFAULT '',
    source_hu_eq_uom String DEFAULT '',
    dest_hu_code String DEFAULT '',
    source_bucket String DEFAULT '',
    drop_quant_bucket String DEFAULT '',
    pd_previous_task_id String DEFAULT '',
    drop_item_previous_task_id String DEFAULT '',
    input_source_bin_id String DEFAULT '',
    provisional_item_id String DEFAULT '',
    pick_item_kind String DEFAULT '',
    tp_assigned_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    leg_index Int32 DEFAULT 0,
    last_leg Bool DEFAULT false,
    ep_assigned_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    carrier_hu_formed_id String DEFAULT '',
    hu_index Int32 DEFAULT 0,
    pick_sequence Int32 DEFAULT 0,
    carrier_hu_force_closed Bool DEFAULT false,
    input_dest_bin_id String DEFAULT '',
    inner_hu_index Int32 DEFAULT 0,
    inner_carrier_hu_key String DEFAULT '',
    inner_carrier_hu_formed_id String DEFAULT '',
    inner_carrier_hu_id String DEFAULT '',
    inner_carrier_hu_code String DEFAULT '',
    inner_carrier_hu_kind String DEFAULT '',
    induction_id String DEFAULT '',
    inner_carrier_hu_force_closed Bool DEFAULT false,
    mhe_id String DEFAULT '',
    pick_attrs String DEFAULT '',
    drop_created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    drop_provisional_item_id String DEFAULT '',
    drop_leg_index Int32 DEFAULT 0,
    drop_last_leg Bool DEFAULT false,
    drop_input_dest_bin_id String DEFAULT '',
    drop_induction_id String DEFAULT '',
    drop_attrs String DEFAULT '',
    drop_mhe_id String DEFAULT ''
)
ENGINE = MergeTree()
PRIMARY KEY (wh_id, pick_item_id, drop_item_id)
ORDER BY (wh_id, pick_item_id, drop_item_id, picked_at)
PARTITION BY toYYYYMM(pick_item_created_at)
SETTINGS index_granularity = 8192;
```

### ClickHouse Performance Optimizations

**Primary Key Strategy:**
- Composite key: `(wh_id, pick_item_id, drop_item_id)`
- Enables efficient warehouse-specific queries
- Supports unique record identification

**Partitioning:**
- Monthly partitions by `pick_item_created_at` timestamp
- Optimizes time-range queries
- Facilitates data lifecycle management

**Ordering:**
- Secondary sort by `picked_at` for time-series queries
- Improves compression and query performance

**Default Values:**
- String fields: Empty string `''`
- Numeric fields: Zero `0` or `0.0`
- Boolean fields: `false`
- DateTime fields: Unix epoch `1970-01-01 00:00:00`
- Date fields: Unix epoch date `1970-01-01`

**Recommended Indexes:**
```sql
-- For worker performance analysis
ALTER TABLE pick_drop_summary ADD INDEX idx_worker (picked_by_worker_id) TYPE bloom_filter(0.01);

-- For SKU analysis
ALTER TABLE pick_drop_summary ADD INDEX idx_picked_sku (picked_sku_id) TYPE bloom_filter(0.01);
ALTER TABLE pick_drop_summary ADD INDEX idx_dropped_sku (dropped_sku_id) TYPE bloom_filter(0.01);

-- For session/task analysis  
ALTER TABLE pick_drop_summary ADD INDEX idx_session (session_id) TYPE bloom_filter(0.01);
ALTER TABLE pick_drop_summary ADD INDEX idx_task (task_id) TYPE bloom_filter(0.01);
```