-- ClickHouse table for WMS Inventory Hourly Position
-- Stores hourly aggregated inventory positions with delta tracking
-- Matches the full detail level of wms_inventory_events_enriched

CREATE TABLE IF NOT EXISTS wms_inventory_hourly_position
(
    -- Time and warehouse
    hour_window DateTime COMMENT 'Hour window for this aggregation',
    wh_id Int64 DEFAULT 0 COMMENT 'Warehouse ID',
    
    -- Core inventory identifiers (GROUP BY keys)
    hu_id String DEFAULT '' COMMENT 'Handling unit ID',
    hu_code String DEFAULT '' COMMENT 'Handling unit code',
    sku_id String DEFAULT '' COMMENT 'SKU ID',
    uom String DEFAULT '' COMMENT 'Unit of measure',
    bucket String DEFAULT '' COMMENT 'Inventory bucket/category',
    batch String DEFAULT '' COMMENT 'Batch identifier',
    price String DEFAULT '' COMMENT 'Price bucket',
    inclusion_status String DEFAULT '' COMMENT 'Inclusion status for inventory',
    locked_by_task_id String DEFAULT '' COMMENT 'Task that has locked this inventory',
    lock_mode String DEFAULT '' COMMENT 'Lock mode (shared/exclusive)',
    
    -- Aggregated metrics for this hour (delta only, not cumulative)
    hourly_qty_change SimpleAggregateFunction(sum, Int64) COMMENT 'Net quantity change in this hour',
    event_count SimpleAggregateFunction(sum, UInt64) COMMENT 'Number of events in this hour',
    
    -- Event identifiers
    hu_event_id SimpleAggregateFunction(anyLast, String),
    quant_event_id SimpleAggregateFunction(anyLast, String),
    first_event_time SimpleAggregateFunction(min, DateTime64(3)) COMMENT 'Earliest event in this hour',
    last_event_time SimpleAggregateFunction(max, DateTime64(3)) COMMENT 'Latest event in this hour',
    
    -- Handling unit event fields
    hu_event_seq SimpleAggregateFunction(anyLast, Int64),
    hu_event_type SimpleAggregateFunction(anyLast, String),
    hu_event_payload SimpleAggregateFunction(anyLast, String),
    hu_event_attrs SimpleAggregateFunction(anyLast, String),
    session_id SimpleAggregateFunction(anyLast, String),
    task_id SimpleAggregateFunction(anyLast, String),
    correlation_id SimpleAggregateFunction(anyLast, String),
    storage_id SimpleAggregateFunction(anyLast, String),
    outer_hu_id SimpleAggregateFunction(anyLast, String),
    effective_storage_id SimpleAggregateFunction(anyLast, String),
    quant_iloc SimpleAggregateFunction(anyLast, String),
    
    -- Handling unit attributes
    hu_state SimpleAggregateFunction(anyLast, String),
    hu_attrs SimpleAggregateFunction(anyLast, String),
    hu_created_at SimpleAggregateFunction(anyLast, DateTime64(3)),
    hu_updated_at SimpleAggregateFunction(anyLast, DateTime64(3)),
    hu_lock_task_id SimpleAggregateFunction(anyLast, String),
    hu_effective_storage_id SimpleAggregateFunction(anyLast, String),
    
    -- Handling unit kind fields
    hu_kind_id SimpleAggregateFunction(anyLast, String),
    hu_kind_code SimpleAggregateFunction(anyLast, String),
    hu_kind_name SimpleAggregateFunction(anyLast, String),
    hu_kind_attrs SimpleAggregateFunction(anyLast, String),
    hu_kind_max_volume SimpleAggregateFunction(anyLast, Float64),
    hu_kind_max_weight SimpleAggregateFunction(anyLast, Float64),
    hu_kind_usage_type SimpleAggregateFunction(anyLast, String),
    hu_kind_abbr SimpleAggregateFunction(anyLast, String),
    hu_kind_length SimpleAggregateFunction(anyLast, Float64),
    hu_kind_breadth SimpleAggregateFunction(anyLast, Float64),
    hu_kind_height SimpleAggregateFunction(anyLast, Float64),
    hu_kind_weight SimpleAggregateFunction(anyLast, Float64),
    
    -- Storage bin fields (from effective_storage enrichment)
    storage_bin_code SimpleAggregateFunction(anyLast, String),
    storage_bin_description SimpleAggregateFunction(anyLast, String),
    storage_bin_status SimpleAggregateFunction(anyLast, String),
    storage_bin_hu_id SimpleAggregateFunction(anyLast, String),
    storage_multi_sku SimpleAggregateFunction(anyLast, Bool),
    storage_multi_batch SimpleAggregateFunction(anyLast, Bool),
    storage_picking_position SimpleAggregateFunction(anyLast, Int32),
    storage_putaway_position SimpleAggregateFunction(anyLast, Int32),
    storage_rank SimpleAggregateFunction(anyLast, Int32),
    storage_aisle SimpleAggregateFunction(anyLast, String),
    storage_bay SimpleAggregateFunction(anyLast, String),
    storage_level SimpleAggregateFunction(anyLast, String),
    storage_position SimpleAggregateFunction(anyLast, String),
    storage_depth SimpleAggregateFunction(anyLast, String),
    storage_max_sku_count SimpleAggregateFunction(anyLast, Int32),
    storage_max_sku_batch_count SimpleAggregateFunction(anyLast, Int32),
    storage_bin_type_id SimpleAggregateFunction(anyLast, String),
    storage_bin_type_code SimpleAggregateFunction(anyLast, String),
    storage_bin_type_description SimpleAggregateFunction(anyLast, String),
    storage_max_volume_in_cc SimpleAggregateFunction(anyLast, Float64),
    storage_max_weight_in_kg SimpleAggregateFunction(anyLast, Float64),
    storage_pallet_capacity SimpleAggregateFunction(anyLast, Int32),
    storage_hu_type SimpleAggregateFunction(anyLast, String),
    storage_auxiliary_bin SimpleAggregateFunction(anyLast, Bool),
    storage_hu_multi_sku SimpleAggregateFunction(anyLast, Bool),
    storage_hu_multi_batch SimpleAggregateFunction(anyLast, Bool),
    storage_use_derived_pallet_best_fit SimpleAggregateFunction(anyLast, Bool),
    storage_only_full_pallet SimpleAggregateFunction(anyLast, Bool),
    storage_zone_id SimpleAggregateFunction(anyLast, String),
    storage_zone_code SimpleAggregateFunction(anyLast, String),
    storage_zone_description SimpleAggregateFunction(anyLast, String),
    storage_zone_face SimpleAggregateFunction(anyLast, String),
    storage_peripheral SimpleAggregateFunction(anyLast, Bool),
    storage_surveillance_config SimpleAggregateFunction(anyLast, String),
    storage_area_id SimpleAggregateFunction(anyLast, String),
    storage_area_code SimpleAggregateFunction(anyLast, String),
    storage_area_description SimpleAggregateFunction(anyLast, String),
    storage_area_type SimpleAggregateFunction(anyLast, String),
    storage_rolling_days SimpleAggregateFunction(anyLast, Int32),
    storage_x1 SimpleAggregateFunction(anyLast, Float64),
    storage_x2 SimpleAggregateFunction(anyLast, Float64),
    storage_y1 SimpleAggregateFunction(anyLast, Float64),
    storage_y2 SimpleAggregateFunction(anyLast, Float64),
    storage_attrs SimpleAggregateFunction(anyLast, String),
    storage_bin_mapping SimpleAggregateFunction(anyLast, String),
    
    -- SKU fields
    sku_code SimpleAggregateFunction(anyLast, String),
    sku_name SimpleAggregateFunction(anyLast, String),
    sku_short_description SimpleAggregateFunction(anyLast, String),
    sku_description SimpleAggregateFunction(anyLast, String),
    sku_category SimpleAggregateFunction(anyLast, String),
    sku_category_group SimpleAggregateFunction(anyLast, String),
    sku_product SimpleAggregateFunction(anyLast, String),
    sku_product_id SimpleAggregateFunction(anyLast, String),
    sku_brand SimpleAggregateFunction(anyLast, String),
    sku_sub_brand SimpleAggregateFunction(anyLast, String),
    sku_fulfillment_type SimpleAggregateFunction(anyLast, String),
    sku_inventory_type SimpleAggregateFunction(anyLast, String),
    sku_shelf_life SimpleAggregateFunction(anyLast, Int32),
    sku_handling_unit_type SimpleAggregateFunction(anyLast, String),
    sku_principal_id SimpleAggregateFunction(anyLast, Int64),
    
    -- SKU identifiers and tags
    sku_identifier1 SimpleAggregateFunction(anyLast, String),
    sku_identifier2 SimpleAggregateFunction(anyLast, String),
    sku_tag1 SimpleAggregateFunction(anyLast, String),
    sku_tag2 SimpleAggregateFunction(anyLast, String),
    sku_tag3 SimpleAggregateFunction(anyLast, String),
    sku_tag4 SimpleAggregateFunction(anyLast, String),
    sku_tag5 SimpleAggregateFunction(anyLast, String),
    sku_tag6 SimpleAggregateFunction(anyLast, String),
    sku_tag7 SimpleAggregateFunction(anyLast, String),
    sku_tag8 SimpleAggregateFunction(anyLast, String),
    sku_tag9 SimpleAggregateFunction(anyLast, String),
    sku_tag10 SimpleAggregateFunction(anyLast, String),
    
    -- SKU UOM hierarchy L0
    sku_l0_name SimpleAggregateFunction(anyLast, String),
    sku_l0_units SimpleAggregateFunction(anyLast, Int32),
    sku_l0_weight SimpleAggregateFunction(anyLast, Float64),
    sku_l0_volume SimpleAggregateFunction(anyLast, Float64),
    sku_l0_package_type SimpleAggregateFunction(anyLast, String),
    sku_l0_length SimpleAggregateFunction(anyLast, Float64),
    sku_l0_width SimpleAggregateFunction(anyLast, Float64),
    sku_l0_height SimpleAggregateFunction(anyLast, Float64),
    sku_l0_itf_code SimpleAggregateFunction(anyLast, String),
    
    -- SKU UOM hierarchy L1
    sku_l1_name SimpleAggregateFunction(anyLast, String),
    sku_l1_units SimpleAggregateFunction(anyLast, Int32),
    sku_l1_weight SimpleAggregateFunction(anyLast, Float64),
    sku_l1_volume SimpleAggregateFunction(anyLast, Float64),
    sku_l1_package_type SimpleAggregateFunction(anyLast, String),
    sku_l1_length SimpleAggregateFunction(anyLast, Float64),
    sku_l1_width SimpleAggregateFunction(anyLast, Float64),
    sku_l1_height SimpleAggregateFunction(anyLast, Float64),
    sku_l1_itf_code SimpleAggregateFunction(anyLast, String),
    
    -- SKU UOM hierarchy L2
    sku_l2_name SimpleAggregateFunction(anyLast, String),
    sku_l2_units SimpleAggregateFunction(anyLast, Int32),
    sku_l2_weight SimpleAggregateFunction(anyLast, Float64),
    sku_l2_volume SimpleAggregateFunction(anyLast, Float64),
    sku_l2_package_type SimpleAggregateFunction(anyLast, String),
    sku_l2_length SimpleAggregateFunction(anyLast, Float64),
    sku_l2_width SimpleAggregateFunction(anyLast, Float64),
    sku_l2_height SimpleAggregateFunction(anyLast, Float64),
    sku_l2_itf_code SimpleAggregateFunction(anyLast, String),
    
    -- SKU UOM hierarchy L3
    sku_l3_name SimpleAggregateFunction(anyLast, String),
    sku_l3_units SimpleAggregateFunction(anyLast, Int32),
    sku_l3_weight SimpleAggregateFunction(anyLast, Float64),
    sku_l3_volume SimpleAggregateFunction(anyLast, Float64),
    sku_l3_package_type SimpleAggregateFunction(anyLast, String),
    sku_l3_length SimpleAggregateFunction(anyLast, Float64),
    sku_l3_width SimpleAggregateFunction(anyLast, Float64),
    sku_l3_height SimpleAggregateFunction(anyLast, Float64),
    sku_l3_itf_code SimpleAggregateFunction(anyLast, String),
    
    -- SKU packaging config
    sku_cases_per_layer SimpleAggregateFunction(anyLast, Int32),
    sku_layers SimpleAggregateFunction(anyLast, Int32),
    sku_avg_l0_per_put SimpleAggregateFunction(anyLast, Int32),
    sku_combined_classification SimpleAggregateFunction(anyLast, String),
    
    -- Outer HU fields
    outer_hu_code SimpleAggregateFunction(anyLast, String),
    outer_hu_kind_id SimpleAggregateFunction(anyLast, String),
    outer_hu_session_id SimpleAggregateFunction(anyLast, String),
    outer_hu_task_id SimpleAggregateFunction(anyLast, String),
    outer_hu_storage_id SimpleAggregateFunction(anyLast, String),
    outer_hu_outer_hu_id SimpleAggregateFunction(anyLast, String),
    outer_hu_state SimpleAggregateFunction(anyLast, String),
    outer_hu_attrs SimpleAggregateFunction(anyLast, String),
    outer_hu_lock_task_id SimpleAggregateFunction(anyLast, String),
    
    -- Outer HU kind fields
    outer_hu_kind_code SimpleAggregateFunction(anyLast, String),
    outer_hu_kind_name SimpleAggregateFunction(anyLast, String),
    outer_hu_kind_attrs SimpleAggregateFunction(anyLast, String),
    outer_hu_kind_max_volume SimpleAggregateFunction(anyLast, Float64),
    outer_hu_kind_max_weight SimpleAggregateFunction(anyLast, Float64),
    outer_hu_kind_usage_type SimpleAggregateFunction(anyLast, String),
    outer_hu_kind_abbr SimpleAggregateFunction(anyLast, String),
    outer_hu_kind_length SimpleAggregateFunction(anyLast, Float64),
    outer_hu_kind_breadth SimpleAggregateFunction(anyLast, Float64),
    outer_hu_kind_height SimpleAggregateFunction(anyLast, Float64),
    outer_hu_kind_weight SimpleAggregateFunction(anyLast, Float64)
)
ENGINE = AggregatingMergeTree()
PARTITION BY toYYYYMM(hour_window)
ORDER BY (wh_id, hour_window, hu_id, sku_id, uom, bucket, batch)
SETTINGS index_granularity = 8192,
         min_age_to_force_merge_seconds = 180
COMMENT 'Hourly aggregated inventory positions with full enriched dimension data';