-- Raw events table for WMS Inventory Events Enriched
-- This table stores enriched inventory movement events with full dimensional data
-- Source: Kafka topic sbx_uat.wms.flink.inventory_events_enriched (obsolete - now using enrichment MVs)
-- This is the base table that feeds the hourly position snapshots

CREATE TABLE IF NOT EXISTS wms_inventory_events_enriched
(
    -- Event identifiers (required - no defaults)
    hu_event_id String,
    quant_event_id String,
    wh_id Int64 DEFAULT 0,
    
    -- Handling unit event fields
    hu_event_seq Int64 DEFAULT 0,
    hu_id String DEFAULT '',
    hu_event_type String DEFAULT '',
    hu_event_timestamp DateTime64(3),
    hu_event_payload String DEFAULT '',
    hu_event_attrs String DEFAULT '',
    session_id String DEFAULT '',
    task_id String DEFAULT '',
    correlation_id String DEFAULT '',
    storage_id String DEFAULT '',
    outer_hu_id String DEFAULT '',
    effective_storage_id String DEFAULT '',
    
    -- Handling unit quant event fields
    sku_id String DEFAULT '',
    uom String DEFAULT '',
    bucket String DEFAULT '',
    batch String DEFAULT '',
    price String DEFAULT '',
    inclusion_status String DEFAULT '',
    locked_by_task_id String DEFAULT '',
    lock_mode String DEFAULT '',
    qty_added Int32 DEFAULT 0,
    quant_iloc String DEFAULT '',  -- Added to match Flink sink structure
    
    -- Enriched handling unit fields
    hu_code String DEFAULT '',
    hu_kind_id String DEFAULT '',
    hu_state String DEFAULT '',
    hu_attrs String DEFAULT '',
    hu_created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    hu_updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    hu_lock_task_id String DEFAULT '',
    hu_effective_storage_id String DEFAULT '',
    
    -- Enriched handling unit kind fields
    hu_kind_code String DEFAULT '',
    hu_kind_name String DEFAULT '',
    hu_kind_attrs String DEFAULT '',
    hu_kind_max_volume Float64 DEFAULT 0,
    hu_kind_max_weight Float64 DEFAULT 0,
    hu_kind_usage_type String DEFAULT '',
    hu_kind_abbr String DEFAULT '',
    hu_kind_length Float64 DEFAULT 0,
    hu_kind_breadth Float64 DEFAULT 0,
    hu_kind_height Float64 DEFAULT 0,
    hu_kind_weight Float64 DEFAULT 0,
    
    
    -- Enriched SKU master fields
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
    sku_principal_id Int64 DEFAULT 0,
    
    -- SKU identifiers and tags
    sku_identifier1 String DEFAULT '',
    sku_identifier2 String DEFAULT '',
    sku_tag1 String DEFAULT '',
    sku_tag2 String DEFAULT '',
    sku_tag3 String DEFAULT '',
    sku_tag4 String DEFAULT '',
    sku_tag5 String DEFAULT '',
    sku_tag6 String DEFAULT '',
    sku_tag7 String DEFAULT '',
    sku_tag8 String DEFAULT '',
    sku_tag9 String DEFAULT '',
    sku_tag10 String DEFAULT '',
    
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
    
    -- Storage bin fields (from effective_storage)
    storage_bin_code String DEFAULT '',
    storage_bin_description String DEFAULT '',
    storage_bin_status String DEFAULT '',
    storage_bin_hu_id String DEFAULT '',
    storage_multi_sku Boolean DEFAULT false,
    storage_multi_batch Boolean DEFAULT false,
    storage_picking_position Int32 DEFAULT 0,
    storage_putaway_position Int32 DEFAULT 0,
    storage_rank Int32 DEFAULT 0,
    storage_aisle String DEFAULT '',
    storage_bay String DEFAULT '',
    storage_level String DEFAULT '',
    storage_position String DEFAULT '',
    storage_depth String DEFAULT '',
    storage_max_sku_count Int32 DEFAULT 0,
    storage_max_sku_batch_count Int32 DEFAULT 0,
    storage_bin_type_id String DEFAULT '',
    storage_bin_type_code String DEFAULT '',
    storage_bin_type_description String DEFAULT '',
    storage_max_volume_in_cc Float64 DEFAULT 0,
    storage_max_weight_in_kg Float64 DEFAULT 0,
    storage_pallet_capacity Int32 DEFAULT 0,
    storage_hu_type String DEFAULT '',
    storage_auxiliary_bin Boolean DEFAULT false,
    storage_hu_multi_sku Boolean DEFAULT false,
    storage_hu_multi_batch Boolean DEFAULT false,
    storage_use_derived_pallet_best_fit Boolean DEFAULT false,
    storage_only_full_pallet Boolean DEFAULT false,
    storage_zone_id String DEFAULT '',
    storage_zone_code String DEFAULT '',
    storage_zone_description String DEFAULT '',
    storage_zone_face String DEFAULT '',
    storage_peripheral Boolean DEFAULT false,
    storage_surveillance_config String DEFAULT '',
    storage_area_id String DEFAULT '',
    storage_area_code String DEFAULT '',
    storage_area_description String DEFAULT '',
    storage_area_type String DEFAULT '',
    storage_rolling_days Int32 DEFAULT 0,
    storage_x1 Float64 DEFAULT 0,
    storage_x2 Float64 DEFAULT 0,
    storage_y1 Float64 DEFAULT 0,
    storage_y2 Float64 DEFAULT 0,
    storage_attrs String DEFAULT '',
    storage_bin_mapping String DEFAULT '',
    
    -- Enriched outer HU fields
    outer_hu_code String DEFAULT '',
    outer_hu_kind_id String DEFAULT '',
    outer_hu_session_id String DEFAULT '',
    outer_hu_task_id String DEFAULT '',
    outer_hu_storage_id String DEFAULT '',
    outer_hu_outer_hu_id String DEFAULT '',
    outer_hu_state String DEFAULT '',
    outer_hu_attrs String DEFAULT '',
    outer_hu_lock_task_id String DEFAULT '',
    outer_hu_kind_code String DEFAULT '',
    outer_hu_kind_name String DEFAULT '',
    outer_hu_kind_attrs String DEFAULT '',
    outer_hu_kind_max_volume Float64 DEFAULT 0,
    outer_hu_kind_max_weight Float64 DEFAULT 0,
    outer_hu_kind_usage_type String DEFAULT '',
    outer_hu_kind_abbr String DEFAULT '',
    outer_hu_kind_length Float64 DEFAULT 0,
    outer_hu_kind_breadth Float64 DEFAULT 0,
    outer_hu_kind_height Float64 DEFAULT 0,
    outer_hu_kind_weight Float64 DEFAULT 0,
    
    -- Ingestion metadata
    _ingested_at DateTime64(3) DEFAULT now64(3)
)
ENGINE = ReplacingMergeTree(_ingested_at)
PARTITION BY toYYYYMM(hu_event_timestamp)
ORDER BY (
    wh_id,
    hu_event_timestamp,
    hu_event_id,
    quant_event_id
)
SETTINGS index_granularity = 8192,
         min_age_to_force_merge_seconds = 180,
         deduplicate_merge_projection_mode = 'drop';

-- Create indexes for common query patterns
-- Note: If indexes already exist, this will fail silently - that's expected behavior
-- The indexes are created once and persist across table recreations
ALTER TABLE wms_inventory_events_enriched ADD INDEX IF NOT EXISTS idx_hu_code hu_code TYPE bloom_filter(0.01) GRANULARITY 4;
ALTER TABLE wms_inventory_events_enriched ADD INDEX IF NOT EXISTS idx_sku_code sku_code TYPE bloom_filter(0.01) GRANULARITY 4;
ALTER TABLE wms_inventory_events_enriched ADD INDEX IF NOT EXISTS idx_storage_bin storage_bin_code TYPE bloom_filter(0.01) GRANULARITY 4;
ALTER TABLE wms_inventory_events_enriched ADD INDEX IF NOT EXISTS idx_batch batch TYPE bloom_filter(0.01) GRANULARITY 4;