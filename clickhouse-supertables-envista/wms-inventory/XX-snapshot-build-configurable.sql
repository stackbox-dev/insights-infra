-- Single Snapshot Build Script for WMS Inventory
-- This script builds exactly one inventory snapshot for a specific timestamp
-- Designed to be called repeatedly by a bash script for each hour

-- CONFIGURATION: Pass these parameters when running the script
-- snapshot_timestamp: The exact timestamp for the snapshot (must be hour-aligned)
--   Example: '2024-01-15 14:00:00'

-- Usage example:
-- clickhouse-client --param_snapshot_timestamp='2024-01-15 14:00:00' --queries-file XX-snapshot-build-configurable.sql
INSERT INTO wms_inventory_snapshot
SELECT
    {snapshot_timestamp:DateTime} as snapshot_timestamp,
    'scheduled' as snapshot_type,
    wh_id,
    
    -- Core inventory identifiers
    hu_id,
    argMax(hu_code, hu_event_timestamp) as hu_code,
    sku_id,
    uom,
    bucket,
    batch,
    price,
    inclusion_status,
    locked_by_task_id,
    lock_mode,
    quant_iloc,
    
    -- Cumulative metrics up to snapshot time
    sum(qty_added) as cumulative_qty,
    count() as total_event_count,
    
    -- Latest event identifiers
    argMax(hu_event_id, hu_event_timestamp) as hu_event_id,
    argMax(quant_event_id, hu_event_timestamp) as quant_event_id,
    max(hu_event_timestamp) as last_event_time,
    
    -- Handling unit event fields (latest)
    argMax(hu_event_seq, hu_event_timestamp) as hu_event_seq,
    argMax(hu_event_type, hu_event_timestamp) as hu_event_type,
    argMax(hu_event_payload, hu_event_timestamp) as hu_event_payload,
    argMax(hu_event_attrs, hu_event_timestamp) as hu_event_attrs,
    argMax(session_id, hu_event_timestamp) as session_id,
    argMax(task_id, hu_event_timestamp) as task_id,
    argMax(correlation_id, hu_event_timestamp) as correlation_id,
    argMax(storage_id, hu_event_timestamp) as storage_id,
    argMax(outer_hu_id, hu_event_timestamp) as outer_hu_id,
    argMax(effective_storage_id, hu_event_timestamp) as effective_storage_id,
    
    -- Handling unit attributes (latest)
    argMax(hu_state, hu_event_timestamp) as hu_state,
    argMax(hu_attrs, hu_event_timestamp) as hu_attrs,
    argMax(hu_created_at, hu_event_timestamp) as hu_created_at,
    argMax(hu_updated_at, hu_event_timestamp) as hu_updated_at,
    argMax(hu_lock_task_id, hu_event_timestamp) as hu_lock_task_id,
    argMax(hu_effective_storage_id, hu_event_timestamp) as hu_effective_storage_id,
    
    -- Handling unit kind fields (latest)
    argMax(hu_kind_id, hu_event_timestamp) as hu_kind_id,
    argMax(hu_kind_code, hu_event_timestamp) as hu_kind_code,
    argMax(hu_kind_name, hu_event_timestamp) as hu_kind_name,
    argMax(hu_kind_attrs, hu_event_timestamp) as hu_kind_attrs,
    argMax(hu_kind_max_volume, hu_event_timestamp) as hu_kind_max_volume,
    argMax(hu_kind_max_weight, hu_event_timestamp) as hu_kind_max_weight,
    argMax(hu_kind_usage_type, hu_event_timestamp) as hu_kind_usage_type,
    argMax(hu_kind_abbr, hu_event_timestamp) as hu_kind_abbr,
    argMax(hu_kind_length, hu_event_timestamp) as hu_kind_length,
    argMax(hu_kind_breadth, hu_event_timestamp) as hu_kind_breadth,
    argMax(hu_kind_height, hu_event_timestamp) as hu_kind_height,
    argMax(hu_kind_weight, hu_event_timestamp) as hu_kind_weight,
    
    -- Storage bin fields (latest)
    argMax(storage_bin_code, hu_event_timestamp) as storage_bin_code,
    argMax(storage_bin_description, hu_event_timestamp) as storage_bin_description,
    argMax(storage_bin_status, hu_event_timestamp) as storage_bin_status,
    argMax(storage_bin_hu_id, hu_event_timestamp) as storage_bin_hu_id,
    argMax(storage_multi_sku, hu_event_timestamp) as storage_multi_sku,
    argMax(storage_multi_batch, hu_event_timestamp) as storage_multi_batch,
    argMax(storage_picking_position, hu_event_timestamp) as storage_picking_position,
    argMax(storage_putaway_position, hu_event_timestamp) as storage_putaway_position,
    argMax(storage_rank, hu_event_timestamp) as storage_rank,
    argMax(storage_aisle, hu_event_timestamp) as storage_aisle,
    argMax(storage_bay, hu_event_timestamp) as storage_bay,
    argMax(storage_level, hu_event_timestamp) as storage_level,
    argMax(storage_position, hu_event_timestamp) as storage_position,
    argMax(storage_depth, hu_event_timestamp) as storage_depth,
    argMax(storage_max_sku_count, hu_event_timestamp) as storage_max_sku_count,
    argMax(storage_max_sku_batch_count, hu_event_timestamp) as storage_max_sku_batch_count,
    argMax(storage_bin_type_id, hu_event_timestamp) as storage_bin_type_id,
    argMax(storage_bin_type_code, hu_event_timestamp) as storage_bin_type_code,
    argMax(storage_bin_type_description, hu_event_timestamp) as storage_bin_type_description,
    argMax(storage_max_volume_in_cc, hu_event_timestamp) as storage_max_volume_in_cc,
    argMax(storage_max_weight_in_kg, hu_event_timestamp) as storage_max_weight_in_kg,
    argMax(storage_pallet_capacity, hu_event_timestamp) as storage_pallet_capacity,
    argMax(storage_hu_type, hu_event_timestamp) as storage_hu_type,
    argMax(storage_auxiliary_bin, hu_event_timestamp) as storage_auxiliary_bin,
    argMax(storage_hu_multi_sku, hu_event_timestamp) as storage_hu_multi_sku,
    argMax(storage_hu_multi_batch, hu_event_timestamp) as storage_hu_multi_batch,
    argMax(storage_use_derived_pallet_best_fit, hu_event_timestamp) as storage_use_derived_pallet_best_fit,
    argMax(storage_only_full_pallet, hu_event_timestamp) as storage_only_full_pallet,
    argMax(storage_zone_id, hu_event_timestamp) as storage_zone_id,
    argMax(storage_zone_code, hu_event_timestamp) as storage_zone_code,
    argMax(storage_zone_description, hu_event_timestamp) as storage_zone_description,
    argMax(storage_zone_face, hu_event_timestamp) as storage_zone_face,
    argMax(storage_peripheral, hu_event_timestamp) as storage_peripheral,
    argMax(storage_surveillance_config, hu_event_timestamp) as storage_surveillance_config,
    argMax(storage_area_id, hu_event_timestamp) as storage_area_id,
    argMax(storage_area_code, hu_event_timestamp) as storage_area_code,
    argMax(storage_area_description, hu_event_timestamp) as storage_area_description,
    argMax(storage_area_type, hu_event_timestamp) as storage_area_type,
    argMax(storage_rolling_days, hu_event_timestamp) as storage_rolling_days,
    argMax(storage_x1, hu_event_timestamp) as storage_x1,
    argMax(storage_x2, hu_event_timestamp) as storage_x2,
    argMax(storage_y1, hu_event_timestamp) as storage_y1,
    argMax(storage_y2, hu_event_timestamp) as storage_y2,
    argMax(storage_attrs, hu_event_timestamp) as storage_attrs,
    argMax(storage_bin_mapping, hu_event_timestamp) as storage_bin_mapping,
    
    -- SKU fields (latest)
    argMax(sku_code, hu_event_timestamp) as sku_code,
    argMax(sku_name, hu_event_timestamp) as sku_name,
    argMax(sku_short_description, hu_event_timestamp) as sku_short_description,
    argMax(sku_description, hu_event_timestamp) as sku_description,
    argMax(sku_category, hu_event_timestamp) as sku_category,
    argMax(sku_category_group, hu_event_timestamp) as sku_category_group,
    argMax(sku_product, hu_event_timestamp) as sku_product,
    argMax(sku_product_id, hu_event_timestamp) as sku_product_id,
    argMax(sku_brand, hu_event_timestamp) as sku_brand,
    argMax(sku_sub_brand, hu_event_timestamp) as sku_sub_brand,
    argMax(sku_fulfillment_type, hu_event_timestamp) as sku_fulfillment_type,
    argMax(sku_inventory_type, hu_event_timestamp) as sku_inventory_type,
    argMax(sku_shelf_life, hu_event_timestamp) as sku_shelf_life,
    argMax(sku_handling_unit_type, hu_event_timestamp) as sku_handling_unit_type,
    argMax(sku_principal_id, hu_event_timestamp) as sku_principal_id,
    
    -- SKU identifiers and tags (latest)
    argMax(sku_identifier1, hu_event_timestamp) as sku_identifier1,
    argMax(sku_identifier2, hu_event_timestamp) as sku_identifier2,
    argMax(sku_tag1, hu_event_timestamp) as sku_tag1,
    argMax(sku_tag2, hu_event_timestamp) as sku_tag2,
    argMax(sku_tag3, hu_event_timestamp) as sku_tag3,
    argMax(sku_tag4, hu_event_timestamp) as sku_tag4,
    argMax(sku_tag5, hu_event_timestamp) as sku_tag5,
    argMax(sku_tag6, hu_event_timestamp) as sku_tag6,
    argMax(sku_tag7, hu_event_timestamp) as sku_tag7,
    argMax(sku_tag8, hu_event_timestamp) as sku_tag8,
    argMax(sku_tag9, hu_event_timestamp) as sku_tag9,
    argMax(sku_tag10, hu_event_timestamp) as sku_tag10,
    
    -- SKU UOM hierarchy L0 (latest)
    argMax(sku_l0_name, hu_event_timestamp) as sku_l0_name,
    argMax(sku_l0_units, hu_event_timestamp) as sku_l0_units,
    argMax(sku_l0_weight, hu_event_timestamp) as sku_l0_weight,
    argMax(sku_l0_volume, hu_event_timestamp) as sku_l0_volume,
    argMax(sku_l0_package_type, hu_event_timestamp) as sku_l0_package_type,
    argMax(sku_l0_length, hu_event_timestamp) as sku_l0_length,
    argMax(sku_l0_width, hu_event_timestamp) as sku_l0_width,
    argMax(sku_l0_height, hu_event_timestamp) as sku_l0_height,
    argMax(sku_l0_itf_code, hu_event_timestamp) as sku_l0_itf_code,
    
    -- SKU UOM hierarchy L1 (latest)
    argMax(sku_l1_name, hu_event_timestamp) as sku_l1_name,
    argMax(sku_l1_units, hu_event_timestamp) as sku_l1_units,
    argMax(sku_l1_weight, hu_event_timestamp) as sku_l1_weight,
    argMax(sku_l1_volume, hu_event_timestamp) as sku_l1_volume,
    argMax(sku_l1_package_type, hu_event_timestamp) as sku_l1_package_type,
    argMax(sku_l1_length, hu_event_timestamp) as sku_l1_length,
    argMax(sku_l1_width, hu_event_timestamp) as sku_l1_width,
    argMax(sku_l1_height, hu_event_timestamp) as sku_l1_height,
    argMax(sku_l1_itf_code, hu_event_timestamp) as sku_l1_itf_code,
    
    -- SKU UOM hierarchy L2 (latest)
    argMax(sku_l2_name, hu_event_timestamp) as sku_l2_name,
    argMax(sku_l2_units, hu_event_timestamp) as sku_l2_units,
    argMax(sku_l2_weight, hu_event_timestamp) as sku_l2_weight,
    argMax(sku_l2_volume, hu_event_timestamp) as sku_l2_volume,
    argMax(sku_l2_package_type, hu_event_timestamp) as sku_l2_package_type,
    argMax(sku_l2_length, hu_event_timestamp) as sku_l2_length,
    argMax(sku_l2_width, hu_event_timestamp) as sku_l2_width,
    argMax(sku_l2_height, hu_event_timestamp) as sku_l2_height,
    argMax(sku_l2_itf_code, hu_event_timestamp) as sku_l2_itf_code,
    
    -- SKU UOM hierarchy L3 (latest)
    argMax(sku_l3_name, hu_event_timestamp) as sku_l3_name,
    argMax(sku_l3_units, hu_event_timestamp) as sku_l3_units,
    argMax(sku_l3_weight, hu_event_timestamp) as sku_l3_weight,
    argMax(sku_l3_volume, hu_event_timestamp) as sku_l3_volume,
    argMax(sku_l3_package_type, hu_event_timestamp) as sku_l3_package_type,
    argMax(sku_l3_length, hu_event_timestamp) as sku_l3_length,
    argMax(sku_l3_width, hu_event_timestamp) as sku_l3_width,
    argMax(sku_l3_height, hu_event_timestamp) as sku_l3_height,
    argMax(sku_l3_itf_code, hu_event_timestamp) as sku_l3_itf_code,
    
    -- SKU packaging config (latest)
    argMax(sku_cases_per_layer, hu_event_timestamp) as sku_cases_per_layer,
    argMax(sku_layers, hu_event_timestamp) as sku_layers,
    argMax(sku_avg_l0_per_put, hu_event_timestamp) as sku_avg_l0_per_put,
    argMax(sku_combined_classification, hu_event_timestamp) as sku_combined_classification,
    
    -- Outer HU fields (latest)
    argMax(outer_hu_code, hu_event_timestamp) as outer_hu_code,
    argMax(outer_hu_kind_id, hu_event_timestamp) as outer_hu_kind_id,
    argMax(outer_hu_session_id, hu_event_timestamp) as outer_hu_session_id,
    argMax(outer_hu_task_id, hu_event_timestamp) as outer_hu_task_id,
    argMax(outer_hu_storage_id, hu_event_timestamp) as outer_hu_storage_id,
    argMax(outer_hu_outer_hu_id, hu_event_timestamp) as outer_hu_outer_hu_id,
    argMax(outer_hu_state, hu_event_timestamp) as outer_hu_state,
    argMax(outer_hu_attrs, hu_event_timestamp) as outer_hu_attrs,
    argMax(outer_hu_lock_task_id, hu_event_timestamp) as outer_hu_lock_task_id,
    
    -- Outer HU kind fields (latest)
    argMax(outer_hu_kind_code, hu_event_timestamp) as outer_hu_kind_code,
    argMax(outer_hu_kind_name, hu_event_timestamp) as outer_hu_kind_name,
    argMax(outer_hu_kind_attrs, hu_event_timestamp) as outer_hu_kind_attrs,
    argMax(outer_hu_kind_max_volume, hu_event_timestamp) as outer_hu_kind_max_volume,
    argMax(outer_hu_kind_max_weight, hu_event_timestamp) as outer_hu_kind_max_weight,
    argMax(outer_hu_kind_usage_type, hu_event_timestamp) as outer_hu_kind_usage_type,
    argMax(outer_hu_kind_abbr, hu_event_timestamp) as outer_hu_kind_abbr,
    argMax(outer_hu_kind_length, hu_event_timestamp) as outer_hu_kind_length,
    argMax(outer_hu_kind_breadth, hu_event_timestamp) as outer_hu_kind_breadth,
    argMax(outer_hu_kind_height, hu_event_timestamp) as outer_hu_kind_height,
    argMax(outer_hu_kind_weight, hu_event_timestamp) as outer_hu_kind_weight,
    
    now64(3) as _created_at
FROM wms_inventory_events_enriched FINAL
WHERE hu_event_timestamp <= {snapshot_timestamp:DateTime}
  AND NOT EXISTS (
      SELECT 1 FROM wms_inventory_snapshot 
      WHERE snapshot_timestamp = {snapshot_timestamp:DateTime}
  )
GROUP BY
    wh_id,
    hu_id,
    sku_id,
    uom,
    bucket,
    batch,
    price,
    inclusion_status,
    locked_by_task_id,
    lock_mode,
    quant_iloc
HAVING sum(qty_added) != 0;