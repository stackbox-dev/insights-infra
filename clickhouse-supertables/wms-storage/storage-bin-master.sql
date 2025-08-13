-- ClickHouse table for WMS Storage Bin Master
-- Comprehensive denormalized view of storage bins with types, zones, areas, positions, and mappings
-- Source: sbx_uat.wms.public.storage_bin_master

CREATE TABLE IF NOT EXISTS wms_storage_bin_master
(
    -- Core Bin Identifiers (Composite Primary Key)
    wh_id Int64,
    bin_code String,
    
    -- Bin Basic Information
    bin_id String DEFAULT '',
    bin_description String DEFAULT '',
    bin_status String DEFAULT '',
    bin_hu_id String DEFAULT '',
    
    -- Bin Configuration
    multi_sku Bool DEFAULT false,
    multi_batch Bool DEFAULT false,
    picking_position Int32 DEFAULT 0,
    putaway_position Int32 DEFAULT 0,
    rank Int32 DEFAULT 0,
    max_sku_count Int32 DEFAULT 0,
    max_sku_batch_count Int32 DEFAULT 0,
    
    -- Bin Location Coordinates
    aisle String DEFAULT '',
    bay String DEFAULT '',
    level String DEFAULT '',
    position String DEFAULT '',
    depth String DEFAULT '',
    
    -- Bin Type Details
    bin_type_id String DEFAULT '',
    bin_type_code String DEFAULT '',
    bin_type_description String DEFAULT '',
    max_volume_in_cc Float64 DEFAULT 0,
    max_weight_in_kg Float64 DEFAULT 0,
    pallet_capacity Int32 DEFAULT 0,
    storage_hu_type String DEFAULT '',
    auxiliary_bin Bool DEFAULT false,
    hu_multi_sku Bool DEFAULT false,
    hu_multi_batch Bool DEFAULT false,
    use_derived_pallet_best_fit Bool DEFAULT false,
    only_full_pallet Bool DEFAULT false,
    bin_type_active Bool DEFAULT false,
    
    -- Zone Information
    zone_id String DEFAULT '',
    zone_code String DEFAULT '',
    zone_description String DEFAULT '',
    zone_face String DEFAULT '',
    peripheral Bool DEFAULT false,
    surveillance_config String DEFAULT '{}',  -- JSON stored as String
    zone_active Bool DEFAULT false,
    
    -- Area Information
    area_id String DEFAULT '',
    area_code String DEFAULT '',
    area_description String DEFAULT '',
    area_type String DEFAULT '',
    rolling_days Int32 DEFAULT 0,
    area_active Bool DEFAULT false,
    
    -- Position Coordinates
    x1 Float64 DEFAULT 0,
    x2 Float64 DEFAULT 0,
    y1 Float64 DEFAULT 0,
    y2 Float64 DEFAULT 0,
    position_active Bool DEFAULT false,
    
    -- Additional Fields
    attrs String DEFAULT '{}',  -- JSON stored as String
    bin_mapping String DEFAULT 'DYNAMIC',  -- FIXED or DYNAMIC
    
    -- Individual table timestamps
    bin_created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    bin_updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    bin_type_created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    bin_type_updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    zone_created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    zone_updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    area_created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    area_updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    position_created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    position_updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    mapping_created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    mapping_updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    
    -- Aggregated metadata
    created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    
    -- Indexes for faster lookups in enrichment
    INDEX idx_bin_id bin_id TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_wh_id wh_id TYPE minmax GRANULARITY 1,
    INDEX idx_bin_code bin_code TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_zone_code zone_code TYPE bloom_filter(0.01) GRANULARITY 4,
    INDEX idx_area_code area_code TYPE bloom_filter(0.01) GRANULARITY 4
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (bin_id)
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop',
         min_age_to_force_merge_seconds = 180
COMMENT 'Comprehensive storage bin master data with types, zones, areas, positions, and mapping configurations';

-- Projection optimized for warehouse + bin_code queries
ALTER TABLE wms_storage_bin_master ADD PROJECTION proj_by_wh_code (
    SELECT 
        wh_id,
        bin_code,
        bin_id,
        bin_description,
        bin_status,
        bin_hu_id,
        multi_sku,
        multi_batch,
        picking_position,
        putaway_position,
        rank,
        aisle,
        bay,
        level,
        position,
        depth,
        bin_type_code,
        zone_id,
        zone_code,
        zone_description,
        area_id,
        area_code,
        area_description,
        x1,
        y1,
        max_volume_in_cc,
        max_weight_in_kg,
        pallet_capacity
    ORDER BY (wh_id, bin_code)
);

-- Projection for zone/area analytics
ALTER TABLE wms_storage_bin_master ADD PROJECTION proj_by_zone_area (
    SELECT 
        wh_id,
        zone_code,
        area_code,
        bin_code,
        bin_id,
        picking_position,
        putaway_position
    ORDER BY (wh_id, zone_code, area_code)
);