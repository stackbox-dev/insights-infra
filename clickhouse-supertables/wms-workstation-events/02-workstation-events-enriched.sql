-- ClickHouse table for WMS Workstation Events Enriched
-- Enriched workstation events with dimension data from handling_units, storage_bin_master, and SKUs
-- Target table for enrichment MV

CREATE TABLE IF NOT EXISTS wms_workstation_events_enriched
(
    -- Core fields from staging
    event_type String,
    event_source_id String,
    event_timestamp DateTime64(3),
    created_at DateTime64(3),
    wh_id Int64,
    sku_id String,
    hu_id String,
    hu_code String,
    batch_id String,
    user_id String,
    task_id String,
    session_id String,
    bin_id String,
    primary_quantity Int64,
    secondary_quantity Int64,
    tertiary_quantity Int64,
    price String,
    status_or_bucket String,
    reason String,
    sub_reason String,
    deactivated_at DateTime64(3),
    
    -- Handling Unit enrichment fields
    hu_enriched_code String DEFAULT '',
    hu_kind_id String DEFAULT '',
    hu_session_id String DEFAULT '',
    hu_task_id String DEFAULT '',
    hu_storage_id String DEFAULT '',
    hu_outer_hu_id String DEFAULT '',
    hu_state String DEFAULT '',
    hu_attrs String DEFAULT '{}',
    hu_lock_task_id String DEFAULT '',
    hu_effective_storage_id String DEFAULT '',
    hu_created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    hu_updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    
    -- Storage Bin Master enrichment fields
    bin_code String DEFAULT '',
    bin_created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    bin_updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    bin_description String DEFAULT '',
    bin_status String DEFAULT '',
    bin_hu_id String DEFAULT '',
    multi_sku Bool DEFAULT false,
    multi_batch Bool DEFAULT false,
    picking_position Int32 DEFAULT 0,
    putaway_position Int32 DEFAULT 0,
    bin_rank Int32 DEFAULT 0,
    aisle String DEFAULT '',
    bay String DEFAULT '',
    level String DEFAULT '',
    bin_position String DEFAULT '',
    depth String DEFAULT '',
    bin_type_code String DEFAULT '',
    zone_id String DEFAULT '',
    zone_code String DEFAULT '',
    zone_description String DEFAULT '',
    area_id String DEFAULT '',
    area_code String DEFAULT '',
    area_description String DEFAULT '',
    x1 Float64 DEFAULT 0,
    y1 Float64 DEFAULT 0,
    max_volume_in_cc Float64 DEFAULT 0,
    max_weight_in_kg Float64 DEFAULT 0,
    pallet_capacity Int32 DEFAULT 0,
    
    -- SKU enrichment fields
    sku_code String DEFAULT '',
    sku_name String DEFAULT '',
    sku_short_description String DEFAULT '',
    sku_description String DEFAULT '',
    sku_category String DEFAULT '',
    sku_category_group String DEFAULT '',
    sku_product String DEFAULT '',
    sku_product_id String DEFAULT '',
    sku_brand String DEFAULT '',
    sku_sub_brand String DEFAULT '',
    sku_fulfillment_type String DEFAULT '',
    sku_inventory_type String DEFAULT '',
    sku_shelf_life Int32 DEFAULT 0,
    sku_handling_unit_type String DEFAULT '',
    sku_active Bool DEFAULT false,
    
    -- SKU identifiers and tags
    sku_identifier1 String DEFAULT '',
    sku_identifier2 String DEFAULT '',
    sku_tag1 String DEFAULT '',
    sku_tag2 String DEFAULT '',
    sku_tag3 String DEFAULT '',
    sku_tag4 String DEFAULT '',
    sku_tag5 String DEFAULT '',
    
    -- SKU UOM hierarchy L0
    sku_l0_name String DEFAULT '',
    sku_l0_units Int32 DEFAULT 0,
    sku_l0_weight Float64 DEFAULT 0,
    sku_l0_volume Float64 DEFAULT 0,
    sku_l0_package_type String DEFAULT '',
    sku_l0_length Float64 DEFAULT 0,
    sku_l0_width Float64 DEFAULT 0,
    sku_l0_height Float64 DEFAULT 0,
    sku_l0_itf_code String DEFAULT '',
    
    -- SKU UOM hierarchy L1
    sku_l1_name String DEFAULT '',
    sku_l1_units Int32 DEFAULT 0,
    sku_l1_weight Float64 DEFAULT 0,
    sku_l1_volume Float64 DEFAULT 0,
    sku_l1_package_type String DEFAULT '',
    sku_l1_length Float64 DEFAULT 0,
    sku_l1_width Float64 DEFAULT 0,
    sku_l1_height Float64 DEFAULT 0,
    sku_l1_itf_code String DEFAULT '',
    
    -- SKU UOM hierarchy L2
    sku_l2_name String DEFAULT '',
    sku_l2_units Int32 DEFAULT 0,
    sku_l2_weight Float64 DEFAULT 0,
    sku_l2_volume Float64 DEFAULT 0,
    sku_l2_package_type String DEFAULT '',
    sku_l2_length Float64 DEFAULT 0,
    sku_l2_width Float64 DEFAULT 0,
    sku_l2_height Float64 DEFAULT 0,
    sku_l2_itf_code String DEFAULT '',
    
    -- SKU UOM hierarchy L3
    sku_l3_name String DEFAULT '',
    sku_l3_units Int32 DEFAULT 0,
    sku_l3_weight Float64 DEFAULT 0,
    sku_l3_volume Float64 DEFAULT 0,
    sku_l3_package_type String DEFAULT '',
    sku_l3_length Float64 DEFAULT 0,
    sku_l3_width Float64 DEFAULT 0,
    sku_l3_height Float64 DEFAULT 0,
    sku_l3_itf_code String DEFAULT '',
    
    -- SKU packaging config
    sku_cases_per_layer Int32 DEFAULT 0,
    sku_layers Int32 DEFAULT 0,
    sku_avg_l0_per_put Int32 DEFAULT 0,
    
    -- SKU classifications
    sku_combined_classification String DEFAULT '',
    
    -- Indexes for query performance
    INDEX idx_wh_id wh_id TYPE minmax GRANULARITY 1,
    INDEX idx_event_timestamp event_timestamp TYPE minmax GRANULARITY 1,
    INDEX idx_event_type event_type TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_user_id user_id TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_task_id task_id TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_session_id session_id TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_sku_id sku_id TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_hu_id hu_id TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_bin_id bin_id TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_bin_code bin_code TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_sku_code sku_code TYPE bloom_filter(0.01) GRANULARITY 1
)
ENGINE = ReplacingMergeTree(event_timestamp)
PARTITION BY toYYYYMM(event_timestamp)
ORDER BY (wh_id, event_type, event_source_id)
TTL toDateTime(deactivated_at) + INTERVAL 0 SECOND DELETE WHERE deactivated_at > toDateTime64('1970-01-01 00:00:00', 3)
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop',
         min_age_to_force_merge_seconds = 180
COMMENT 'Enriched workstation events with full dimension data for analytics';