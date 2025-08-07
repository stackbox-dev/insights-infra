# WMS Storage Tables Documentation

This document covers three key warehouse storage management tables that provide comprehensive views of storage infrastructure, locations, and configurations.

---

## 1. Storage Area SLOC Mapping Table

### Overview
The `storage_area_sloc_mapping` table provides the mapping between storage areas and Storage Location (SLOC) codes, which are critical for ERP-WMS integration and inventory visibility management.

### Table Details
- **Name**: `storage_area_sloc_mapping`
- **Topic**: `sbx_uat.wms.public.storage_area_sloc_mapping`
- **Primary Key**: `(wh_id, area_code, quality, sloc)` - Composite key
- **Connector**: `upsert-kafka` with Avro-Confluent format

### Field Categories

#### Core Identifiers
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `wh_id` | BIGINT | No | Warehouse identifier (PK) |
| `area_code` | STRING | No | Storage area code (PK) |
| `quality` | STRING | No | Quality classification (PK) |
| `sloc` | STRING | No | Storage location code for ERP (PK) |

#### SLOC Configuration
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `sloc_description` | STRING | Yes | Description of the storage location |
| `client_quality` | STRING | Yes | Client-specific quality designation |
| `inventory_visible` | BOOLEAN | Yes | Whether inventory is visible in this SLOC |
| `erp_to_wms` | BOOLEAN | Yes | Whether data flows from ERP to WMS |
| `iloc` | STRING | Yes | Internal location code |

#### System Fields
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `deactivatedAt` | TIMESTAMP(3) | Yes | When the mapping was deactivated |
| `createdAt` | TIMESTAMP(3) | Yes | Record creation timestamp |
| `updatedAt` | TIMESTAMP(3) | Yes | Last update timestamp |
| `is_snapshot` | BOOLEAN | Yes | CDC snapshot indicator |

### Usage Patterns
- **ERP Integration**: Maps WMS storage areas to ERP storage locations
- **Quality Management**: Segregates inventory by quality status
- **Visibility Control**: Manages which locations are visible for inventory reporting

---

## 2. Storage Bin Master Table

### Overview
The `storage_bin_master` table is a comprehensive denormalized view that combines storage bins with their types, zones, areas, positions, and fixed mapping configurations to provide a complete picture of warehouse storage infrastructure.

### Table Details
- **Name**: `storage_bin_master`
- **Topic**: `sbx_uat.wms.public.storage_bin_master`
- **Primary Key**: `(wh_id, bin_code)` - Composite key
- **Connector**: `upsert-kafka` with Avro-Confluent format
- **Total Columns**: 46

### Field Categories

#### Core Bin Identifiers
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `wh_id` | BIGINT | No | Warehouse identifier (PK) |
| `bin_id` | STRING | Yes | Unique bin identifier |
| `bin_code` | STRING | No | Bin code (PK) |
| `bin_description` | STRING | Yes | Bin description |
| `bin_status` | STRING | Yes | Current bin status |
| `bin_hu_id` | STRING | Yes | Associated handling unit ID |

#### Bin Configuration
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `multi_sku` | BOOLEAN | Yes | Whether bin can hold multiple SKUs |
| `multi_batch` | BOOLEAN | Yes | Whether bin can hold multiple batches |
| `picking_position` | INT | Yes | Priority for picking operations |
| `putaway_position` | INT | Yes | Priority for putaway operations |
| `rank` | INT | Yes | Bin ranking/priority |
| `max_sku_count` | INT | Yes | Maximum number of SKUs allowed |
| `max_sku_batch_count` | INT | Yes | Maximum SKU-batch combinations |

#### Bin Location Coordinates
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `aisle` | STRING | Yes | Aisle identifier |
| `bay` | STRING | Yes | Bay identifier |
| `level` | STRING | Yes | Vertical level |
| `position` | STRING | Yes | Position within bay |
| `depth` | STRING | Yes | Depth position |

#### Bin Type Details
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `bin_type_id` | STRING | Yes | Bin type identifier |
| `bin_type_code` | STRING | Yes | Bin type code |
| `bin_type_description` | STRING | Yes | Bin type description |
| `max_volume_in_cc` | DOUBLE | Yes | Maximum volume in cubic centimeters |
| `max_weight_in_kg` | DOUBLE | Yes | Maximum weight in kilograms |
| `pallet_capacity` | INT | Yes | Number of pallets bin can hold |
| `storage_hu_type` | STRING | Yes | Type of handling units stored |
| `auxiliary_bin` | BOOLEAN | Yes | Whether bin is auxiliary storage |
| `hu_multi_sku` | BOOLEAN | Yes | Whether HU can contain multiple SKUs |
| `hu_multi_batch` | BOOLEAN | Yes | Whether HU can contain multiple batches |
| `use_derived_pallet_best_fit` | BOOLEAN | Yes | Use algorithm for pallet optimization |
| `only_full_pallet` | BOOLEAN | Yes | Accept only full pallets |
| `bin_type_active` | BOOLEAN | Yes | Whether bin type is active |

#### Zone Information
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `zone_id` | STRING | Yes | Zone identifier |
| `zone_code` | STRING | Yes | Zone code |
| `zone_description` | STRING | Yes | Zone description |
| `zone_face` | STRING | Yes | Zone face/side designation |
| `peripheral` | BOOLEAN | Yes | Whether zone is peripheral |
| `surveillance_config` | STRING | Yes | Surveillance configuration (JSON) |
| `zone_active` | BOOLEAN | Yes | Whether zone is active |

#### Area Information
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `area_id` | STRING | Yes | Area identifier |
| `area_code` | STRING | Yes | Area code |
| `area_description` | STRING | Yes | Area description |
| `area_type` | STRING | Yes | Type of storage area |
| `rolling_days` | INT | Yes | Rolling inventory days |
| `area_active` | BOOLEAN | Yes | Whether area is active |

#### Position Coordinates
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `x1` | DOUBLE | Yes | X1 coordinate for bin position |
| `x2` | DOUBLE | Yes | X2 coordinate for bin position |
| `y1` | DOUBLE | Yes | Y1 coordinate for bin position |
| `y2` | DOUBLE | Yes | Y2 coordinate for bin position |
| `position_active` | BOOLEAN | Yes | Whether position is active |

#### Additional Fields
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `attrs` | STRING | Yes | Additional attributes (JSON) |
| `bin_mapping` | STRING | Yes | 'FIXED' or 'DYNAMIC' mapping type |
| `createdAt` | TIMESTAMP(3) | Yes | Creation timestamp |
| `updatedAt` | TIMESTAMP(3) | Yes | Last update timestamp |
| `is_snapshot` | BOOLEAN | Yes | CDC snapshot indicator |

### Data Processing Logic
- **Join Strategy**: Combines 6 source tables through INNER and LEFT JOINs
- **Mapping Type**: Determines FIXED/DYNAMIC based on active fixed mappings
- **Snapshot Logic**: Combines snapshots using AND logic across all sources

### Usage Patterns
- **Warehouse Layout**: Complete view of warehouse storage structure
- **Capacity Planning**: Analysis of storage capacity and constraints
- **Slotting Optimization**: Data for optimal product placement decisions
- **Navigation**: Coordinate-based warehouse navigation

---

## 3. Storage Bin Dockdoor Master Table

### Overview
The `storage_bin_dockdoor_master` table maps storage bins to dock doors, providing essential data for inbound/outbound logistics operations and staging area management.

### Table Details
- **Name**: `storage_bin_dockdoor_master`
- **Topic**: `sbx_uat.wms.public.storage_bin_dockdoor_master`
- **Primary Key**: `(wh_id, bin_code, dockdoor_code)` - Composite key
- **Connector**: `upsert-kafka` with Avro-Confluent format

### Field Categories

#### Core Identifiers
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `wh_id` | BIGINT | No | Warehouse identifier (PK) |
| `bin_id` | STRING | Yes | Unique bin identifier |
| `bin_code` | STRING | No | Bin code (PK) |
| `dockdoor_id` | STRING | Yes | Dock door identifier |
| `dockdoor_code` | STRING | No | Dock door code (PK) |

#### Dock Door Configuration
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `dockdoor_description` | STRING | Yes | Dock door description |
| `usage` | STRING | Yes | Usage type (INBOUND/OUTBOUND/BOTH) |
| `active` | BOOLEAN | Yes | Whether mapping is active |
| `dock_handling_unit` | STRING | Yes | Default handling unit type |
| `multi_trip` | BOOLEAN | Yes | Whether supports multiple trips |

#### Dock Door Capabilities
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `max_queue` | BIGINT | Yes | Maximum queue size |
| `allow_inbound` | BOOLEAN | Yes | Whether allows inbound shipments |
| `allow_outbound` | BOOLEAN | Yes | Whether allows outbound shipments |
| `allow_returns` | BOOLEAN | Yes | Whether allows returns processing |
| `dockdoor_status` | STRING | Yes | Current dock door status |

#### Compatibility Constraints
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `incompatible_vehicle_types` | STRING | Yes | List of incompatible vehicle types |
| `incompatible_load_types` | STRING | Yes | List of incompatible load types |

#### Position Information
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `dockdoor_x_coordinate` | DOUBLE | Yes | X coordinate of dock door |
| `dockdoor_y_coordinate` | DOUBLE | Yes | Y coordinate of dock door |
| `dockdoor_position_active` | BOOLEAN | Yes | Whether position is active |

#### System Fields
| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `createdAt` | TIMESTAMP(3) | Yes | Creation timestamp |
| `updatedAt` | TIMESTAMP(3) | Yes | Last update timestamp |
| `is_snapshot` | BOOLEAN | Yes | CDC snapshot indicator |

### Data Processing Logic
- **Join Strategy**: Combines storage bins with dock doors through bin-dockdoor mappings
- **Position Enrichment**: Adds dock door position coordinates
- **Timestamp Logic**: Uses GREATEST to find latest timestamp across sources

### Usage Patterns
- **Staging Management**: Identifies staging bins for specific dock doors
- **Load Planning**: Matches vehicle types with compatible dock doors
- **Cross-Docking**: Facilitates efficient cross-dock operations
- **Returns Processing**: Identifies doors configured for returns

---

## Common Integration Points

### Pipeline Dependencies

All three tables share common characteristics:
- **Source System**: WMS (Warehouse Management System)
- **Data Flow**: CDC (Change Data Capture) from PostgreSQL via Debezium
- **Serialization**: Avro with Confluent Schema Registry
- **Delivery Guarantee**: Exactly-once semantics with upsert-kafka

### Performance Characteristics
- **Transaction Prefixes**: Each sink table has unique transaction ID prefix
- **Parallelism**: Optimized for distributed processing
- **State Management**: Maintains CDC snapshot flags for consistency

### Best Practices

#### Query Optimization
- Use composite primary keys for efficient lookups
- Filter by `wh_id` first for partition pruning
- Leverage `active` flags to exclude inactive records

#### Data Quality
- Validate coordinate consistency for positions
- Check referential integrity across joined tables
- Monitor for orphaned mappings

#### Maintenance
- Regular cleanup of deactivated records
- Periodic validation of bin-zone-area hierarchies
- Audit fixed vs dynamic mapping assignments