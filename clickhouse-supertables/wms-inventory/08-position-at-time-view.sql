-- Optimized parameterized view for inventory position at any point in time
-- Uses UNION ALL approach for 3-tier architecture (snapshot + hourly + raw events)
-- Includes ALL columns from enriched events table (with removed columns excluded)

DROP VIEW IF EXISTS wms_inventory_position_at_time;

CREATE VIEW wms_inventory_position_at_time AS
WITH 
-- Parameters
param_wh_id AS (SELECT {wh_id:Int64} as value),
param_target_time AS (SELECT {target_time:DateTime64(3)} as value),
target_hour AS (SELECT toStartOfHour((SELECT value FROM param_target_time)) as value),

-- Find the most recent weekly snapshot before target time
latest_snapshot_time AS (
    SELECT COALESCE(max(snapshot_timestamp), toDateTime('1970-01-01')) as value
    FROM wms_inventory_weekly_snapshot
    WHERE wh_id = (SELECT value FROM param_wh_id)
      AND snapshot_timestamp <= (SELECT value FROM param_target_time)
),

-- Combine all three data sources using UNION ALL
all_positions AS (
    -- 1. Weekly snapshot data (base cumulative quantities)
    SELECT 
        -- Core inventory identifiers
        wh_id,
        hu_id,
        hu_code,
        sku_id,
        uom,
        bucket,
        batch,
        price,
        inclusion_status,
        locked_by_task_id,
        lock_mode,
        
        -- Quantity and time
        cumulative_qty as qty_change,
        snapshot_timestamp as event_time,
        
        -- Event identifiers
        hu_event_id,
        quant_event_id,
        
        -- Handling unit event fields
        hu_event_seq,
        hu_event_type,
        hu_event_payload,
        hu_event_attrs,
        session_id,
        task_id,
        correlation_id,
        storage_id,
        outer_hu_id,
        effective_storage_id,
        quant_iloc,
        
        -- Handling unit attributes
        hu_state,
        hu_attrs,
        hu_created_at,
        hu_updated_at,
        hu_lock_task_id,
        hu_effective_storage_id,
        
        -- Handling unit kind fields
        hu_kind_id,
        hu_kind_code,
        hu_kind_name,
        hu_kind_attrs,
        hu_kind_max_volume,
        hu_kind_max_weight,
        hu_kind_usage_type,
        hu_kind_abbr,
        hu_kind_length,
        hu_kind_breadth,
        hu_kind_height,
        hu_kind_weight,
        
        -- SKU basic fields
        sku_code,
        sku_name,
        sku_short_description,
        sku_description,
        sku_category,
        sku_category_group,
        sku_product,
        sku_product_id,
        sku_brand,
        sku_sub_brand,
        sku_fulfillment_type,
        sku_inventory_type,
        sku_shelf_life,
        sku_handling_unit_type,
        sku_principal_id,
        
        -- SKU identifiers and tags
        sku_identifier1,
        sku_identifier2,
        sku_tag1,
        sku_tag2,
        sku_tag3,
        sku_tag4,
        sku_tag5,
        sku_tag6,
        sku_tag7,
        sku_tag8,
        sku_tag9,
        sku_tag10,
        
        -- SKU UOM hierarchy L0
        sku_l0_name,
        sku_l0_units,
        sku_l0_weight,
        sku_l0_volume,
        sku_l0_package_type,
        sku_l0_length,
        sku_l0_width,
        sku_l0_height,
        sku_l0_itf_code,
        
        -- SKU UOM hierarchy L1
        sku_l1_name,
        sku_l1_units,
        sku_l1_weight,
        sku_l1_volume,
        sku_l1_package_type,
        sku_l1_length,
        sku_l1_width,
        sku_l1_height,
        sku_l1_itf_code,
        
        -- SKU UOM hierarchy L2
        sku_l2_name,
        sku_l2_units,
        sku_l2_weight,
        sku_l2_volume,
        sku_l2_package_type,
        sku_l2_length,
        sku_l2_width,
        sku_l2_height,
        sku_l2_itf_code,
        
        -- SKU UOM hierarchy L3
        sku_l3_name,
        sku_l3_units,
        sku_l3_weight,
        sku_l3_volume,
        sku_l3_package_type,
        sku_l3_length,
        sku_l3_width,
        sku_l3_height,
        sku_l3_itf_code,
        
        -- SKU packaging config
        sku_cases_per_layer,
        sku_layers,
        sku_avg_l0_per_put,
        sku_combined_classification,
        
        -- Storage bin fields
        storage_bin_code,
        storage_bin_description,
        storage_bin_status,
        storage_bin_hu_id,
        storage_multi_sku,
        storage_multi_batch,
        storage_picking_position,
        storage_putaway_position,
        storage_rank,
        storage_aisle,
        storage_bay,
        storage_level,
        storage_position,
        storage_depth,
        storage_max_sku_count,
        storage_max_sku_batch_count,
        storage_bin_type_id,
        storage_bin_type_code,
        storage_bin_type_description,
        storage_max_volume_in_cc,
        storage_max_weight_in_kg,
        storage_pallet_capacity,
        storage_hu_type,
        storage_auxiliary_bin,
        storage_hu_multi_sku,
        storage_hu_multi_batch,
        storage_use_derived_pallet_best_fit,
        storage_only_full_pallet,
        storage_zone_id,
        storage_zone_code,
        storage_zone_description,
        storage_zone_face,
        storage_peripheral,
        storage_surveillance_config,
        storage_area_id,
        storage_area_code,
        storage_area_description,
        storage_area_type,
        storage_rolling_days,
        storage_x1,
        storage_x2,
        storage_y1,
        storage_y2,
        storage_attrs,
        storage_bin_mapping,
        
        -- Outer HU fields
        outer_hu_code,
        outer_hu_kind_id,
        outer_hu_session_id,
        outer_hu_task_id,
        outer_hu_storage_id,
        outer_hu_outer_hu_id,
        outer_hu_state,
        outer_hu_attrs,
        outer_hu_lock_task_id,
        
        -- Outer HU kind fields
        outer_hu_kind_code,
        outer_hu_kind_name,
        outer_hu_kind_attrs,
        outer_hu_kind_max_volume,
        outer_hu_kind_max_weight,
        outer_hu_kind_usage_type,
        outer_hu_kind_abbr,
        outer_hu_kind_length,
        outer_hu_kind_breadth,
        outer_hu_kind_height,
        outer_hu_kind_weight
    FROM wms_inventory_weekly_snapshot
    WHERE wh_id = (SELECT value FROM param_wh_id)
      AND snapshot_timestamp = (SELECT value FROM latest_snapshot_time)
      AND (SELECT value FROM latest_snapshot_time) != toDateTime('1970-01-01')  -- Only if snapshot exists
    
    UNION ALL
    
    -- 2. Hourly position changes (between snapshot and current hour)
    SELECT 
        -- Core inventory identifiers
        wh_id,
        hu_id,
        hu_code,
        sku_id,
        uom,
        bucket,
        batch,
        price,
        inclusion_status,
        locked_by_task_id,
        lock_mode,
        
        -- Quantity and time
        hourly_qty_change as qty_change,
        hour_window as event_time,
        
        -- Event identifiers
        hu_event_id,
        quant_event_id,
        
        -- Handling unit event fields
        hu_event_seq,
        hu_event_type,
        hu_event_payload,
        hu_event_attrs,
        session_id,
        task_id,
        correlation_id,
        storage_id,
        outer_hu_id,
        effective_storage_id,
        quant_iloc,
        
        -- Handling unit attributes
        hu_state,
        hu_attrs,
        hu_created_at,
        hu_updated_at,
        hu_lock_task_id,
        hu_effective_storage_id,
        
        -- Handling unit kind fields
        hu_kind_id,
        hu_kind_code,
        hu_kind_name,
        hu_kind_attrs,
        hu_kind_max_volume,
        hu_kind_max_weight,
        hu_kind_usage_type,
        hu_kind_abbr,
        hu_kind_length,
        hu_kind_breadth,
        hu_kind_height,
        hu_kind_weight,
        
        -- SKU basic fields
        sku_code,
        sku_name,
        sku_short_description,
        sku_description,
        sku_category,
        sku_category_group,
        sku_product,
        sku_product_id,
        sku_brand,
        sku_sub_brand,
        sku_fulfillment_type,
        sku_inventory_type,
        sku_shelf_life,
        sku_handling_unit_type,
        sku_principal_id,
        
        -- SKU identifiers and tags
        sku_identifier1,
        sku_identifier2,
        sku_tag1,
        sku_tag2,
        sku_tag3,
        sku_tag4,
        sku_tag5,
        sku_tag6,
        sku_tag7,
        sku_tag8,
        sku_tag9,
        sku_tag10,
        
        -- SKU UOM hierarchy L0
        sku_l0_name,
        sku_l0_units,
        sku_l0_weight,
        sku_l0_volume,
        sku_l0_package_type,
        sku_l0_length,
        sku_l0_width,
        sku_l0_height,
        sku_l0_itf_code,
        
        -- SKU UOM hierarchy L1
        sku_l1_name,
        sku_l1_units,
        sku_l1_weight,
        sku_l1_volume,
        sku_l1_package_type,
        sku_l1_length,
        sku_l1_width,
        sku_l1_height,
        sku_l1_itf_code,
        
        -- SKU UOM hierarchy L2
        sku_l2_name,
        sku_l2_units,
        sku_l2_weight,
        sku_l2_volume,
        sku_l2_package_type,
        sku_l2_length,
        sku_l2_width,
        sku_l2_height,
        sku_l2_itf_code,
        
        -- SKU UOM hierarchy L3
        sku_l3_name,
        sku_l3_units,
        sku_l3_weight,
        sku_l3_volume,
        sku_l3_package_type,
        sku_l3_length,
        sku_l3_width,
        sku_l3_height,
        sku_l3_itf_code,
        
        -- SKU packaging config
        sku_cases_per_layer,
        sku_layers,
        sku_avg_l0_per_put,
        sku_combined_classification,
        
        -- Storage bin fields
        storage_bin_code,
        storage_bin_description,
        storage_bin_status,
        storage_bin_hu_id,
        storage_multi_sku,
        storage_multi_batch,
        storage_picking_position,
        storage_putaway_position,
        storage_rank,
        storage_aisle,
        storage_bay,
        storage_level,
        storage_position,
        storage_depth,
        storage_max_sku_count,
        storage_max_sku_batch_count,
        storage_bin_type_id,
        storage_bin_type_code,
        storage_bin_type_description,
        storage_max_volume_in_cc,
        storage_max_weight_in_kg,
        storage_pallet_capacity,
        storage_hu_type,
        storage_auxiliary_bin,
        storage_hu_multi_sku,
        storage_hu_multi_batch,
        storage_use_derived_pallet_best_fit,
        storage_only_full_pallet,
        storage_zone_id,
        storage_zone_code,
        storage_zone_description,
        storage_zone_face,
        storage_peripheral,
        storage_surveillance_config,
        storage_area_id,
        storage_area_code,
        storage_area_description,
        storage_area_type,
        storage_rolling_days,
        storage_x1,
        storage_x2,
        storage_y1,
        storage_y2,
        storage_attrs,
        storage_bin_mapping,
        
        -- Outer HU fields
        outer_hu_code,
        outer_hu_kind_id,
        outer_hu_session_id,
        outer_hu_task_id,
        outer_hu_storage_id,
        outer_hu_outer_hu_id,
        outer_hu_state,
        outer_hu_attrs,
        outer_hu_lock_task_id,
        
        -- Outer HU kind fields
        outer_hu_kind_code,
        outer_hu_kind_name,
        outer_hu_kind_attrs,
        outer_hu_kind_max_volume,
        outer_hu_kind_max_weight,
        outer_hu_kind_usage_type,
        outer_hu_kind_abbr,
        outer_hu_kind_length,
        outer_hu_kind_breadth,
        outer_hu_kind_height,
        outer_hu_kind_weight
    FROM wms_inventory_hourly_position
    WHERE wh_id = (SELECT value FROM param_wh_id)
      AND hour_window > (SELECT value FROM latest_snapshot_time)
      AND hour_window < (SELECT value FROM target_hour)
    
    UNION ALL
    
    -- 3. Current hour events (raw events with FINAL for deduplication)
    SELECT 
        -- Core inventory identifiers
        wh_id,
        hu_id,
        hu_code,
        sku_id,
        uom,
        bucket,
        batch,
        price,
        inclusion_status,
        locked_by_task_id,
        lock_mode,
        
        -- Quantity and time
        qty_added as qty_change,
        hu_event_timestamp as event_time,
        
        -- Event identifiers
        hu_event_id,
        quant_event_id,
        
        -- Handling unit event fields
        hu_event_seq,
        hu_event_type,
        hu_event_payload,
        hu_event_attrs,
        session_id,
        task_id,
        correlation_id,
        storage_id,
        outer_hu_id,
        effective_storage_id,
        quant_iloc,
        
        -- Handling unit attributes
        hu_state,
        hu_attrs,
        hu_created_at,
        hu_updated_at,
        hu_lock_task_id,
        hu_effective_storage_id,
        
        -- Handling unit kind fields
        hu_kind_id,
        hu_kind_code,
        hu_kind_name,
        hu_kind_attrs,
        hu_kind_max_volume,
        hu_kind_max_weight,
        hu_kind_usage_type,
        hu_kind_abbr,
        hu_kind_length,
        hu_kind_breadth,
        hu_kind_height,
        hu_kind_weight,
        
        -- SKU basic fields
        sku_code,
        sku_name,
        sku_short_description,
        sku_description,
        sku_category,
        sku_category_group,
        sku_product,
        sku_product_id,
        sku_brand,
        sku_sub_brand,
        sku_fulfillment_type,
        sku_inventory_type,
        sku_shelf_life,
        sku_handling_unit_type,
        sku_principal_id,
        
        -- SKU identifiers and tags
        sku_identifier1,
        sku_identifier2,
        sku_tag1,
        sku_tag2,
        sku_tag3,
        sku_tag4,
        sku_tag5,
        sku_tag6,
        sku_tag7,
        sku_tag8,
        sku_tag9,
        sku_tag10,
        
        -- SKU UOM hierarchy L0
        sku_l0_name,
        sku_l0_units,
        sku_l0_weight,
        sku_l0_volume,
        sku_l0_package_type,
        sku_l0_length,
        sku_l0_width,
        sku_l0_height,
        sku_l0_itf_code,
        
        -- SKU UOM hierarchy L1
        sku_l1_name,
        sku_l1_units,
        sku_l1_weight,
        sku_l1_volume,
        sku_l1_package_type,
        sku_l1_length,
        sku_l1_width,
        sku_l1_height,
        sku_l1_itf_code,
        
        -- SKU UOM hierarchy L2
        sku_l2_name,
        sku_l2_units,
        sku_l2_weight,
        sku_l2_volume,
        sku_l2_package_type,
        sku_l2_length,
        sku_l2_width,
        sku_l2_height,
        sku_l2_itf_code,
        
        -- SKU UOM hierarchy L3
        sku_l3_name,
        sku_l3_units,
        sku_l3_weight,
        sku_l3_volume,
        sku_l3_package_type,
        sku_l3_length,
        sku_l3_width,
        sku_l3_height,
        sku_l3_itf_code,
        
        -- SKU packaging config
        sku_cases_per_layer,
        sku_layers,
        sku_avg_l0_per_put,
        sku_combined_classification,
        
        -- Storage bin fields
        storage_bin_code,
        storage_bin_description,
        storage_bin_status,
        storage_bin_hu_id,
        storage_multi_sku,
        storage_multi_batch,
        storage_picking_position,
        storage_putaway_position,
        storage_rank,
        storage_aisle,
        storage_bay,
        storage_level,
        storage_position,
        storage_depth,
        storage_max_sku_count,
        storage_max_sku_batch_count,
        storage_bin_type_id,
        storage_bin_type_code,
        storage_bin_type_description,
        storage_max_volume_in_cc,
        storage_max_weight_in_kg,
        storage_pallet_capacity,
        storage_hu_type,
        storage_auxiliary_bin,
        storage_hu_multi_sku,
        storage_hu_multi_batch,
        storage_use_derived_pallet_best_fit,
        storage_only_full_pallet,
        storage_zone_id,
        storage_zone_code,
        storage_zone_description,
        storage_zone_face,
        storage_peripheral,
        storage_surveillance_config,
        storage_area_id,
        storage_area_code,
        storage_area_description,
        storage_area_type,
        storage_rolling_days,
        storage_x1,
        storage_x2,
        storage_y1,
        storage_y2,
        storage_attrs,
        storage_bin_mapping,
        
        -- Outer HU fields
        outer_hu_code,
        outer_hu_kind_id,
        outer_hu_session_id,
        outer_hu_task_id,
        outer_hu_storage_id,
        outer_hu_outer_hu_id,
        outer_hu_state,
        outer_hu_attrs,
        outer_hu_lock_task_id,
        
        -- Outer HU kind fields
        outer_hu_kind_code,
        outer_hu_kind_name,
        outer_hu_kind_attrs,
        outer_hu_kind_max_volume,
        outer_hu_kind_max_weight,
        outer_hu_kind_usage_type,
        outer_hu_kind_abbr,
        outer_hu_kind_length,
        outer_hu_kind_breadth,
        outer_hu_kind_height,
        outer_hu_kind_weight
    FROM wms_inventory_events_enriched FINAL
    WHERE wh_id = (SELECT value FROM param_wh_id)
      AND hu_event_timestamp >= (SELECT value FROM target_hour)
      AND hu_event_timestamp <= (SELECT value FROM param_target_time)
)

-- Final aggregation to combine all sources
SELECT 
    -- Core inventory identifiers
    wh_id,
    hu_id,
    hu_code,
    sku_id,
    uom,
    bucket,
    batch,
    price,
    inclusion_status,
    locked_by_task_id,
    lock_mode,
    
    -- Aggregated metrics
    sum(qty_change) as quantity,
    count() as total_events,
    max(event_time) as last_update_time,
    
    -- Event identifiers (latest)
    argMax(hu_event_id, event_time) as hu_event_id,
    argMax(quant_event_id, event_time) as quant_event_id,
    
    -- Handling unit event fields (latest)
    argMax(hu_event_seq, event_time) as hu_event_seq,
    argMax(hu_event_type, event_time) as hu_event_type,
    argMax(hu_event_payload, event_time) as hu_event_payload,
    argMax(hu_event_attrs, event_time) as hu_event_attrs,
    argMax(session_id, event_time) as session_id,
    argMax(task_id, event_time) as task_id,
    argMax(correlation_id, event_time) as correlation_id,
    argMax(storage_id, event_time) as storage_id,
    argMax(outer_hu_id, event_time) as outer_hu_id,
    argMax(effective_storage_id, event_time) as effective_storage_id,
    argMax(quant_iloc, event_time) as quant_iloc,
    
    -- Handling unit attributes (latest)
    argMax(hu_state, event_time) as hu_state,
    argMax(hu_attrs, event_time) as hu_attrs,
    argMax(hu_created_at, event_time) as hu_created_at,
    argMax(hu_updated_at, event_time) as hu_updated_at,
    argMax(hu_lock_task_id, event_time) as hu_lock_task_id,
    argMax(hu_effective_storage_id, event_time) as hu_effective_storage_id,
    
    -- Handling unit kind fields (latest)
    argMax(hu_kind_id, event_time) as hu_kind_id,
    argMax(hu_kind_code, event_time) as hu_kind_code,
    argMax(hu_kind_name, event_time) as hu_kind_name,
    argMax(hu_kind_attrs, event_time) as hu_kind_attrs,
    argMax(hu_kind_max_volume, event_time) as hu_kind_max_volume,
    argMax(hu_kind_max_weight, event_time) as hu_kind_max_weight,
    argMax(hu_kind_usage_type, event_time) as hu_kind_usage_type,
    argMax(hu_kind_abbr, event_time) as hu_kind_abbr,
    argMax(hu_kind_length, event_time) as hu_kind_length,
    argMax(hu_kind_breadth, event_time) as hu_kind_breadth,
    argMax(hu_kind_height, event_time) as hu_kind_height,
    argMax(hu_kind_weight, event_time) as hu_kind_weight,
    
    -- SKU basic fields (latest)
    argMax(sku_code, event_time) as sku_code,
    argMax(sku_name, event_time) as sku_name,
    argMax(sku_short_description, event_time) as sku_short_description,
    argMax(sku_description, event_time) as sku_description,
    argMax(sku_category, event_time) as sku_category,
    argMax(sku_category_group, event_time) as sku_category_group,
    argMax(sku_product, event_time) as sku_product,
    argMax(sku_product_id, event_time) as sku_product_id,
    argMax(sku_brand, event_time) as sku_brand,
    argMax(sku_sub_brand, event_time) as sku_sub_brand,
    argMax(sku_fulfillment_type, event_time) as sku_fulfillment_type,
    argMax(sku_inventory_type, event_time) as sku_inventory_type,
    argMax(sku_shelf_life, event_time) as sku_shelf_life,
    argMax(sku_handling_unit_type, event_time) as sku_handling_unit_type,
    argMax(sku_principal_id, event_time) as sku_principal_id,
    
    -- SKU identifiers and tags (latest)
    argMax(sku_identifier1, event_time) as sku_identifier1,
    argMax(sku_identifier2, event_time) as sku_identifier2,
    argMax(sku_tag1, event_time) as sku_tag1,
    argMax(sku_tag2, event_time) as sku_tag2,
    argMax(sku_tag3, event_time) as sku_tag3,
    argMax(sku_tag4, event_time) as sku_tag4,
    argMax(sku_tag5, event_time) as sku_tag5,
    argMax(sku_tag6, event_time) as sku_tag6,
    argMax(sku_tag7, event_time) as sku_tag7,
    argMax(sku_tag8, event_time) as sku_tag8,
    argMax(sku_tag9, event_time) as sku_tag9,
    argMax(sku_tag10, event_time) as sku_tag10,
    
    -- SKU UOM hierarchy L0 (latest)
    argMax(sku_l0_name, event_time) as sku_l0_name,
    argMax(sku_l0_units, event_time) as sku_l0_units,
    argMax(sku_l0_weight, event_time) as sku_l0_weight,
    argMax(sku_l0_volume, event_time) as sku_l0_volume,
    argMax(sku_l0_package_type, event_time) as sku_l0_package_type,
    argMax(sku_l0_length, event_time) as sku_l0_length,
    argMax(sku_l0_width, event_time) as sku_l0_width,
    argMax(sku_l0_height, event_time) as sku_l0_height,
    argMax(sku_l0_itf_code, event_time) as sku_l0_itf_code,
    
    -- SKU UOM hierarchy L1 (latest)
    argMax(sku_l1_name, event_time) as sku_l1_name,
    argMax(sku_l1_units, event_time) as sku_l1_units,
    argMax(sku_l1_weight, event_time) as sku_l1_weight,
    argMax(sku_l1_volume, event_time) as sku_l1_volume,
    argMax(sku_l1_package_type, event_time) as sku_l1_package_type,
    argMax(sku_l1_length, event_time) as sku_l1_length,
    argMax(sku_l1_width, event_time) as sku_l1_width,
    argMax(sku_l1_height, event_time) as sku_l1_height,
    argMax(sku_l1_itf_code, event_time) as sku_l1_itf_code,
    
    -- SKU UOM hierarchy L2 (latest)
    argMax(sku_l2_name, event_time) as sku_l2_name,
    argMax(sku_l2_units, event_time) as sku_l2_units,
    argMax(sku_l2_weight, event_time) as sku_l2_weight,
    argMax(sku_l2_volume, event_time) as sku_l2_volume,
    argMax(sku_l2_package_type, event_time) as sku_l2_package_type,
    argMax(sku_l2_length, event_time) as sku_l2_length,
    argMax(sku_l2_width, event_time) as sku_l2_width,
    argMax(sku_l2_height, event_time) as sku_l2_height,
    argMax(sku_l2_itf_code, event_time) as sku_l2_itf_code,
    
    -- SKU UOM hierarchy L3 (latest)
    argMax(sku_l3_name, event_time) as sku_l3_name,
    argMax(sku_l3_units, event_time) as sku_l3_units,
    argMax(sku_l3_weight, event_time) as sku_l3_weight,
    argMax(sku_l3_volume, event_time) as sku_l3_volume,
    argMax(sku_l3_package_type, event_time) as sku_l3_package_type,
    argMax(sku_l3_length, event_time) as sku_l3_length,
    argMax(sku_l3_width, event_time) as sku_l3_width,
    argMax(sku_l3_height, event_time) as sku_l3_height,
    argMax(sku_l3_itf_code, event_time) as sku_l3_itf_code,
    
    -- SKU packaging config (latest)
    argMax(sku_cases_per_layer, event_time) as sku_cases_per_layer,
    argMax(sku_layers, event_time) as sku_layers,
    argMax(sku_avg_l0_per_put, event_time) as sku_avg_l0_per_put,
    argMax(sku_combined_classification, event_time) as sku_combined_classification,
    
    -- Storage bin fields (latest)
    argMax(storage_bin_code, event_time) as storage_bin_code,
    argMax(storage_bin_description, event_time) as storage_bin_description,
    argMax(storage_bin_status, event_time) as storage_bin_status,
    argMax(storage_bin_hu_id, event_time) as storage_bin_hu_id,
    argMax(storage_multi_sku, event_time) as storage_multi_sku,
    argMax(storage_multi_batch, event_time) as storage_multi_batch,
    argMax(storage_picking_position, event_time) as storage_picking_position,
    argMax(storage_putaway_position, event_time) as storage_putaway_position,
    argMax(storage_rank, event_time) as storage_rank,
    argMax(storage_aisle, event_time) as storage_aisle,
    argMax(storage_bay, event_time) as storage_bay,
    argMax(storage_level, event_time) as storage_level,
    argMax(storage_position, event_time) as storage_position,
    argMax(storage_depth, event_time) as storage_depth,
    argMax(storage_max_sku_count, event_time) as storage_max_sku_count,
    argMax(storage_max_sku_batch_count, event_time) as storage_max_sku_batch_count,
    argMax(storage_bin_type_id, event_time) as storage_bin_type_id,
    argMax(storage_bin_type_code, event_time) as storage_bin_type_code,
    argMax(storage_bin_type_description, event_time) as storage_bin_type_description,
    argMax(storage_max_volume_in_cc, event_time) as storage_max_volume_in_cc,
    argMax(storage_max_weight_in_kg, event_time) as storage_max_weight_in_kg,
    argMax(storage_pallet_capacity, event_time) as storage_pallet_capacity,
    argMax(storage_hu_type, event_time) as storage_hu_type,
    argMax(storage_auxiliary_bin, event_time) as storage_auxiliary_bin,
    argMax(storage_hu_multi_sku, event_time) as storage_hu_multi_sku,
    argMax(storage_hu_multi_batch, event_time) as storage_hu_multi_batch,
    argMax(storage_use_derived_pallet_best_fit, event_time) as storage_use_derived_pallet_best_fit,
    argMax(storage_only_full_pallet, event_time) as storage_only_full_pallet,
    argMax(storage_zone_id, event_time) as storage_zone_id,
    argMax(storage_zone_code, event_time) as storage_zone_code,
    argMax(storage_zone_description, event_time) as storage_zone_description,
    argMax(storage_zone_face, event_time) as storage_zone_face,
    argMax(storage_peripheral, event_time) as storage_peripheral,
    argMax(storage_surveillance_config, event_time) as storage_surveillance_config,
    argMax(storage_area_id, event_time) as storage_area_id,
    argMax(storage_area_code, event_time) as storage_area_code,
    argMax(storage_area_description, event_time) as storage_area_description,
    argMax(storage_area_type, event_time) as storage_area_type,
    argMax(storage_rolling_days, event_time) as storage_rolling_days,
    argMax(storage_x1, event_time) as storage_x1,
    argMax(storage_x2, event_time) as storage_x2,
    argMax(storage_y1, event_time) as storage_y1,
    argMax(storage_y2, event_time) as storage_y2,
    argMax(storage_attrs, event_time) as storage_attrs,
    argMax(storage_bin_mapping, event_time) as storage_bin_mapping,
    
    -- Outer HU fields (latest)
    argMax(outer_hu_code, event_time) as outer_hu_code,
    argMax(outer_hu_kind_id, event_time) as outer_hu_kind_id,
    argMax(outer_hu_session_id, event_time) as outer_hu_session_id,
    argMax(outer_hu_task_id, event_time) as outer_hu_task_id,
    argMax(outer_hu_storage_id, event_time) as outer_hu_storage_id,
    argMax(outer_hu_outer_hu_id, event_time) as outer_hu_outer_hu_id,
    argMax(outer_hu_state, event_time) as outer_hu_state,
    argMax(outer_hu_attrs, event_time) as outer_hu_attrs,
    argMax(outer_hu_lock_task_id, event_time) as outer_hu_lock_task_id,
    
    -- Outer HU kind fields (latest)
    argMax(outer_hu_kind_code, event_time) as outer_hu_kind_code,
    argMax(outer_hu_kind_name, event_time) as outer_hu_kind_name,
    argMax(outer_hu_kind_attrs, event_time) as outer_hu_kind_attrs,
    argMax(outer_hu_kind_max_volume, event_time) as outer_hu_kind_max_volume,
    argMax(outer_hu_kind_max_weight, event_time) as outer_hu_kind_max_weight,
    argMax(outer_hu_kind_usage_type, event_time) as outer_hu_kind_usage_type,
    argMax(outer_hu_kind_abbr, event_time) as outer_hu_kind_abbr,
    argMax(outer_hu_kind_length, event_time) as outer_hu_kind_length,
    argMax(outer_hu_kind_breadth, event_time) as outer_hu_kind_breadth,
    argMax(outer_hu_kind_height, event_time) as outer_hu_kind_height,
    argMax(outer_hu_kind_weight, event_time) as outer_hu_kind_weight,
    
    -- Query metadata
    (SELECT value FROM param_target_time) as query_time,
    (SELECT value FROM latest_snapshot_time) as base_snapshot_time
FROM all_positions
GROUP BY 
    wh_id,
    hu_id,
    hu_code,
    sku_id,
    uom,
    bucket,
    batch,
    price,
    inclusion_status,
    locked_by_task_id,
    lock_mode
HAVING quantity != 0
ORDER BY hu_code, sku_code;