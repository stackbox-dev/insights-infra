-- Backfill script for Manual Snapshots with specific week/year selection
-- This script generates historical manual snapshots for specified weeks
-- Run this AFTER hourly position table has been backfilled

-- ========================================
-- OPTION 1: Backfill specific weeks by year and week number
-- ========================================
-- Modify the week_dates CTE to specify exact weeks you want
-- Example: Generate snapshots for weeks 1, 14, 27, 40 of 2024

INSERT INTO wms_inventory_weekly_snapshot
WITH week_dates AS (
    -- MODIFY THIS SECTION to specify exact weeks
    -- Format: toStartOfWeek(toDate('YYYY-MM-DD'))
    -- Example weeks for 2024:
    SELECT toStartOfWeek(toDate('2024-01-01')) as week_date  -- Week 1, 2024
    UNION ALL
    SELECT toStartOfWeek(toDate('2024-04-01')) as week_date  -- Week 14, 2024
    UNION ALL
    SELECT toStartOfWeek(toDate('2024-07-01')) as week_date  -- Week 27, 2024
    UNION ALL
    SELECT toStartOfWeek(toDate('2024-10-01')) as week_date  -- Week 40, 2024
    
    -- Add more weeks as needed:
    -- UNION ALL
    -- SELECT toStartOfWeek(toDate('2023-01-01')) as week_date  -- Week 1, 2023
    -- UNION ALL
    -- SELECT toStartOfWeek(toDate('2023-07-01')) as week_date  -- Week 27, 2023
)
SELECT
    wd.week_date as snapshot_timestamp,
    'manual' as snapshot_type,
    hp.wh_id,
    
    -- Core inventory identifiers
    hp.hu_id,
    hp.hu_code,
    hp.sku_id,
    hp.uom,
    hp.bucket,
    hp.batch,
    hp.price,
    hp.inclusion_status,
    hp.locked_by_task_id,
    hp.lock_mode,
    
    -- Cumulative sum from beginning of time to this week
    sum(hp.hourly_qty_change) as cumulative_qty,
    sum(hp.event_count) as total_event_count,
    
    -- Event identifiers
    argMax(hp.hu_event_id, hp.hour_window) as hu_event_id,
    argMax(hp.quant_event_id, hp.hour_window) as quant_event_id,
    max(hp.last_event_time) as last_event_time,
    
    -- Handling unit event fields
    argMax(hp.hu_event_seq, hp.hour_window) as hu_event_seq,
    argMax(hp.hu_event_type, hp.hour_window) as hu_event_type,
    argMax(hp.hu_event_payload, hp.hour_window) as hu_event_payload,
    argMax(hp.hu_event_attrs, hp.hour_window) as hu_event_attrs,
    argMax(hp.session_id, hp.hour_window) as session_id,
    argMax(hp.task_id, hp.hour_window) as task_id,
    argMax(hp.correlation_id, hp.hour_window) as correlation_id,
    argMax(hp.storage_id, hp.hour_window) as storage_id,
    argMax(hp.outer_hu_id, hp.hour_window) as outer_hu_id,
    argMax(hp.effective_storage_id, hp.hour_window) as effective_storage_id,
    argMax(hp.quant_iloc, hp.hour_window) as quant_iloc,
    
    -- Handling unit attributes
    argMax(hp.hu_state, hp.hour_window) as hu_state,
    argMax(hp.hu_attrs, hp.hour_window) as hu_attrs,
    argMax(hp.hu_created_at, hp.hour_window) as hu_created_at,
    argMax(hp.hu_updated_at, hp.hour_window) as hu_updated_at,
    argMax(hp.hu_lock_task_id, hp.hour_window) as hu_lock_task_id,
    argMax(hp.hu_effective_storage_id, hp.hour_window) as hu_effective_storage_id,
    
    -- Handling unit kind fields
    argMax(hp.hu_kind_id, hp.hour_window) as hu_kind_id,
    argMax(hp.hu_kind_code, hp.hour_window) as hu_kind_code,
    argMax(hp.hu_kind_name, hp.hour_window) as hu_kind_name,
    argMax(hp.hu_kind_attrs, hp.hour_window) as hu_kind_attrs,
    argMax(hp.hu_kind_max_volume, hp.hour_window) as hu_kind_max_volume,
    argMax(hp.hu_kind_max_weight, hp.hour_window) as hu_kind_max_weight,
    argMax(hp.hu_kind_usage_type, hp.hour_window) as hu_kind_usage_type,
    argMax(hp.hu_kind_abbr, hp.hour_window) as hu_kind_abbr,
    argMax(hp.hu_kind_length, hp.hour_window) as hu_kind_length,
    argMax(hp.hu_kind_breadth, hp.hour_window) as hu_kind_breadth,
    argMax(hp.hu_kind_height, hp.hour_window) as hu_kind_height,
    argMax(hp.hu_kind_weight, hp.hour_window) as hu_kind_weight,
    
    -- Storage bin fields (from effective_storage)
    argMax(hp.storage_bin_code, hp.hour_window) as storage_bin_code,
    argMax(hp.storage_bin_description, hp.hour_window) as storage_bin_description,
    argMax(hp.storage_bin_status, hp.hour_window) as storage_bin_status,
    argMax(hp.storage_bin_hu_id, hp.hour_window) as storage_bin_hu_id,
    argMax(hp.storage_multi_sku, hp.hour_window) as storage_multi_sku,
    argMax(hp.storage_multi_batch, hp.hour_window) as storage_multi_batch,
    argMax(hp.storage_picking_position, hp.hour_window) as storage_picking_position,
    argMax(hp.storage_putaway_position, hp.hour_window) as storage_putaway_position,
    argMax(hp.storage_rank, hp.hour_window) as storage_rank,
    argMax(hp.storage_aisle, hp.hour_window) as storage_aisle,
    argMax(hp.storage_bay, hp.hour_window) as storage_bay,
    argMax(hp.storage_level, hp.hour_window) as storage_level,
    argMax(hp.storage_position, hp.hour_window) as storage_position,
    argMax(hp.storage_depth, hp.hour_window) as storage_depth,
    argMax(hp.storage_max_sku_count, hp.hour_window) as storage_max_sku_count,
    argMax(hp.storage_max_sku_batch_count, hp.hour_window) as storage_max_sku_batch_count,
    argMax(hp.storage_bin_type_id, hp.hour_window) as storage_bin_type_id,
    argMax(hp.storage_bin_type_code, hp.hour_window) as storage_bin_type_code,
    argMax(hp.storage_bin_type_description, hp.hour_window) as storage_bin_type_description,
    argMax(hp.storage_max_volume_in_cc, hp.hour_window) as storage_max_volume_in_cc,
    argMax(hp.storage_max_weight_in_kg, hp.hour_window) as storage_max_weight_in_kg,
    argMax(hp.storage_pallet_capacity, hp.hour_window) as storage_pallet_capacity,
    argMax(hp.storage_hu_type, hp.hour_window) as storage_hu_type,
    argMax(hp.storage_auxiliary_bin, hp.hour_window) as storage_auxiliary_bin,
    argMax(hp.storage_hu_multi_sku, hp.hour_window) as storage_hu_multi_sku,
    argMax(hp.storage_hu_multi_batch, hp.hour_window) as storage_hu_multi_batch,
    argMax(hp.storage_use_derived_pallet_best_fit, hp.hour_window) as storage_use_derived_pallet_best_fit,
    argMax(hp.storage_only_full_pallet, hp.hour_window) as storage_only_full_pallet,
    argMax(hp.storage_zone_id, hp.hour_window) as storage_zone_id,
    argMax(hp.storage_zone_code, hp.hour_window) as storage_zone_code,
    argMax(hp.storage_zone_description, hp.hour_window) as storage_zone_description,
    argMax(hp.storage_zone_face, hp.hour_window) as storage_zone_face,
    argMax(hp.storage_peripheral, hp.hour_window) as storage_peripheral,
    argMax(hp.storage_surveillance_config, hp.hour_window) as storage_surveillance_config,
    argMax(hp.storage_area_id, hp.hour_window) as storage_area_id,
    argMax(hp.storage_area_code, hp.hour_window) as storage_area_code,
    argMax(hp.storage_area_description, hp.hour_window) as storage_area_description,
    argMax(hp.storage_area_type, hp.hour_window) as storage_area_type,
    argMax(hp.storage_rolling_days, hp.hour_window) as storage_rolling_days,
    argMax(hp.storage_x1, hp.hour_window) as storage_x1,
    argMax(hp.storage_x2, hp.hour_window) as storage_x2,
    argMax(hp.storage_y1, hp.hour_window) as storage_y1,
    argMax(hp.storage_y2, hp.hour_window) as storage_y2,
    argMax(hp.storage_attrs, hp.hour_window) as storage_attrs,
    argMax(hp.storage_bin_mapping, hp.hour_window) as storage_bin_mapping,
    
    -- SKU fields
    argMax(hp.sku_code, hp.hour_window) as sku_code,
    argMax(hp.sku_name, hp.hour_window) as sku_name,
    argMax(hp.sku_short_description, hp.hour_window) as sku_short_description,
    argMax(hp.sku_description, hp.hour_window) as sku_description,
    argMax(hp.sku_category, hp.hour_window) as sku_category,
    argMax(hp.sku_category_group, hp.hour_window) as sku_category_group,
    argMax(hp.sku_product, hp.hour_window) as sku_product,
    argMax(hp.sku_product_id, hp.hour_window) as sku_product_id,
    argMax(hp.sku_brand, hp.hour_window) as sku_brand,
    argMax(hp.sku_sub_brand, hp.hour_window) as sku_sub_brand,
    argMax(hp.sku_fulfillment_type, hp.hour_window) as sku_fulfillment_type,
    argMax(hp.sku_inventory_type, hp.hour_window) as sku_inventory_type,
    argMax(hp.sku_shelf_life, hp.hour_window) as sku_shelf_life,
    argMax(hp.sku_handling_unit_type, hp.hour_window) as sku_handling_unit_type,
    argMax(hp.sku_principal_id, hp.hour_window) as sku_principal_id,
    
    -- SKU identifiers and tags
    argMax(hp.sku_identifier1, hp.hour_window) as sku_identifier1,
    argMax(hp.sku_identifier2, hp.hour_window) as sku_identifier2,
    argMax(hp.sku_tag1, hp.hour_window) as sku_tag1,
    argMax(hp.sku_tag2, hp.hour_window) as sku_tag2,
    argMax(hp.sku_tag3, hp.hour_window) as sku_tag3,
    argMax(hp.sku_tag4, hp.hour_window) as sku_tag4,
    argMax(hp.sku_tag5, hp.hour_window) as sku_tag5,
    argMax(hp.sku_tag6, hp.hour_window) as sku_tag6,
    argMax(hp.sku_tag7, hp.hour_window) as sku_tag7,
    argMax(hp.sku_tag8, hp.hour_window) as sku_tag8,
    argMax(hp.sku_tag9, hp.hour_window) as sku_tag9,
    argMax(hp.sku_tag10, hp.hour_window) as sku_tag10,
    
    -- SKU UOM hierarchy L0
    argMax(hp.sku_l0_name, hp.hour_window) as sku_l0_name,
    argMax(hp.sku_l0_units, hp.hour_window) as sku_l0_units,
    argMax(hp.sku_l0_weight, hp.hour_window) as sku_l0_weight,
    argMax(hp.sku_l0_volume, hp.hour_window) as sku_l0_volume,
    argMax(hp.sku_l0_package_type, hp.hour_window) as sku_l0_package_type,
    argMax(hp.sku_l0_length, hp.hour_window) as sku_l0_length,
    argMax(hp.sku_l0_width, hp.hour_window) as sku_l0_width,
    argMax(hp.sku_l0_height, hp.hour_window) as sku_l0_height,
    argMax(hp.sku_l0_itf_code, hp.hour_window) as sku_l0_itf_code,
    
    -- SKU UOM hierarchy L1
    argMax(hp.sku_l1_name, hp.hour_window) as sku_l1_name,
    argMax(hp.sku_l1_units, hp.hour_window) as sku_l1_units,
    argMax(hp.sku_l1_weight, hp.hour_window) as sku_l1_weight,
    argMax(hp.sku_l1_volume, hp.hour_window) as sku_l1_volume,
    argMax(hp.sku_l1_package_type, hp.hour_window) as sku_l1_package_type,
    argMax(hp.sku_l1_length, hp.hour_window) as sku_l1_length,
    argMax(hp.sku_l1_width, hp.hour_window) as sku_l1_width,
    argMax(hp.sku_l1_height, hp.hour_window) as sku_l1_height,
    argMax(hp.sku_l1_itf_code, hp.hour_window) as sku_l1_itf_code,
    
    -- SKU UOM hierarchy L2
    argMax(hp.sku_l2_name, hp.hour_window) as sku_l2_name,
    argMax(hp.sku_l2_units, hp.hour_window) as sku_l2_units,
    argMax(hp.sku_l2_weight, hp.hour_window) as sku_l2_weight,
    argMax(hp.sku_l2_volume, hp.hour_window) as sku_l2_volume,
    argMax(hp.sku_l2_package_type, hp.hour_window) as sku_l2_package_type,
    argMax(hp.sku_l2_length, hp.hour_window) as sku_l2_length,
    argMax(hp.sku_l2_width, hp.hour_window) as sku_l2_width,
    argMax(hp.sku_l2_height, hp.hour_window) as sku_l2_height,
    argMax(hp.sku_l2_itf_code, hp.hour_window) as sku_l2_itf_code,
    
    -- SKU UOM hierarchy L3
    argMax(hp.sku_l3_name, hp.hour_window) as sku_l3_name,
    argMax(hp.sku_l3_units, hp.hour_window) as sku_l3_units,
    argMax(hp.sku_l3_weight, hp.hour_window) as sku_l3_weight,
    argMax(hp.sku_l3_volume, hp.hour_window) as sku_l3_volume,
    argMax(hp.sku_l3_package_type, hp.hour_window) as sku_l3_package_type,
    argMax(hp.sku_l3_length, hp.hour_window) as sku_l3_length,
    argMax(hp.sku_l3_width, hp.hour_window) as sku_l3_width,
    argMax(hp.sku_l3_height, hp.hour_window) as sku_l3_height,
    argMax(hp.sku_l3_itf_code, hp.hour_window) as sku_l3_itf_code,
    
    -- SKU packaging config
    argMax(hp.sku_cases_per_layer, hp.hour_window) as sku_cases_per_layer,
    argMax(hp.sku_layers, hp.hour_window) as sku_layers,
    argMax(hp.sku_avg_l0_per_put, hp.hour_window) as sku_avg_l0_per_put,
    argMax(hp.sku_combined_classification, hp.hour_window) as sku_combined_classification,
    
    -- Outer HU fields
    argMax(hp.outer_hu_code, hp.hour_window) as outer_hu_code,
    argMax(hp.outer_hu_kind_id, hp.hour_window) as outer_hu_kind_id,
    argMax(hp.outer_hu_session_id, hp.hour_window) as outer_hu_session_id,
    argMax(hp.outer_hu_task_id, hp.hour_window) as outer_hu_task_id,
    argMax(hp.outer_hu_storage_id, hp.hour_window) as outer_hu_storage_id,
    argMax(hp.outer_hu_outer_hu_id, hp.hour_window) as outer_hu_outer_hu_id,
    argMax(hp.outer_hu_state, hp.hour_window) as outer_hu_state,
    argMax(hp.outer_hu_attrs, hp.hour_window) as outer_hu_attrs,
    argMax(hp.outer_hu_lock_task_id, hp.hour_window) as outer_hu_lock_task_id,
    
    -- Outer HU kind fields
    argMax(hp.outer_hu_kind_code, hp.hour_window) as outer_hu_kind_code,
    argMax(hp.outer_hu_kind_name, hp.hour_window) as outer_hu_kind_name,
    argMax(hp.outer_hu_kind_attrs, hp.hour_window) as outer_hu_kind_attrs,
    argMax(hp.outer_hu_kind_max_volume, hp.hour_window) as outer_hu_kind_max_volume,
    argMax(hp.outer_hu_kind_max_weight, hp.hour_window) as outer_hu_kind_max_weight,
    argMax(hp.outer_hu_kind_usage_type, hp.hour_window) as outer_hu_kind_usage_type,
    argMax(hp.outer_hu_kind_abbr, hp.hour_window) as outer_hu_kind_abbr,
    argMax(hp.outer_hu_kind_length, hp.hour_window) as outer_hu_kind_length,
    argMax(hp.outer_hu_kind_breadth, hp.hour_window) as outer_hu_kind_breadth,
    argMax(hp.outer_hu_kind_height, hp.hour_window) as outer_hu_kind_height,
    argMax(hp.outer_hu_kind_weight, hp.hour_window) as outer_hu_kind_weight,
    
    now64(3) as generated_at
FROM week_dates wd
CROSS JOIN wms_inventory_hourly_position hp
WHERE hp.hour_window < wd.week_date
GROUP BY 
    wd.week_date,
    hp.wh_id,
    hp.hu_id,
    hp.hu_code,
    hp.sku_id,
    hp.uom,
    hp.bucket,
    hp.batch,
    hp.price,
    hp.inclusion_status,
    hp.locked_by_task_id,
    hp.lock_mode
HAVING sum(hp.hourly_qty_change) != 0;

-- ========================================
-- OPTION 2: Generate snapshots for every Nth week
-- ========================================
-- Uncomment and use this alternative approach to generate every 4th week (monthly-ish)

-- INSERT INTO wms_inventory_weekly_snapshot
-- WITH week_dates AS (
--     SELECT toStartOfWeek(
--         toDate('2024-01-01') + INTERVAL (number * 4) WEEK
--     ) as week_date
--     FROM numbers(13)  -- 13 snapshots = quarterly for a year (52/4)
--     WHERE week_date <= now()
-- )
-- ... rest of the SELECT query remains the same

-- ========================================
-- OPTION 3: Generate snapshots for specific date ranges
-- ========================================
-- Generate weekly snapshots for a specific period

-- INSERT INTO wms_inventory_weekly_snapshot
-- WITH week_dates AS (
--     SELECT DISTINCT toStartOfWeek(
--         toDate('2024-01-01') + INTERVAL number WEEK
--     ) as week_date
--     FROM numbers(52)  -- All weeks in 2024
--     WHERE week_date BETWEEN toDate('2024-01-01') AND toDate('2024-12-31')
--       AND week_date <= now()
-- )
-- ... rest of the SELECT query remains the same

-- ========================================
-- Verify backfill results
-- ========================================
SELECT 
    'Backfill complete:' as info,
    min(snapshot_timestamp) as earliest_snapshot,
    max(snapshot_timestamp) as latest_snapshot,
    count(DISTINCT snapshot_timestamp) as total_snapshots,
    count(*) as total_rows,
    count(DISTINCT wh_id) as warehouses
FROM wms_inventory_weekly_snapshot;

-- Check snapshot sizes by week
SELECT 
    snapshot_timestamp,
    count(*) as rows,
    uniq(hu_code) as unique_hus,
    uniq(sku_code) as unique_skus,
    sum(cumulative_qty) as total_qty
FROM wms_inventory_weekly_snapshot
GROUP BY snapshot_timestamp
ORDER BY snapshot_timestamp DESC
LIMIT 20;