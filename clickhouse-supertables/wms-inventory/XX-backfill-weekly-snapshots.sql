-- Backfill script for Weekly Snapshots
-- This script generates historical weekly snapshots - ONLY 2 per year to minimize memory usage
-- Run this AFTER hourly position table has been backfilled
-- Note: For ongoing weekly snapshots, use the automated mechanism in 09_weekly_snapshot_automation.sql

-- IMPORTANT: This processes only 2 weeks per year (January and July) to minimize memory usage
-- If you need more snapshots, run additional queries with different dates

-- Generate weekly snapshots for first Sunday of January and July each year
-- This reduces the data processed by ~96% while still providing reference snapshots

INSERT INTO wms_inventory_weekly_snapshot
WITH date_range AS (
    -- Get the date range from hourly position data
    SELECT 
        toYear(min(hour_window)) as min_year,
        toYear(now()) as max_year
    FROM wms_inventory_hourly_position
),
week_dates AS (
    -- Generate only 2 weeks per year: first Sunday of January and first Sunday of July
    -- This dramatically reduces memory usage by processing only ~4% of weeks
    SELECT DISTINCT week_date
    FROM (
        SELECT toStartOfWeek(toDate(concat(toString(year), '-01-01'))) as week_date
        FROM (
            SELECT min_year + number as year
            FROM date_range
            ARRAY JOIN range(0, toUInt32(max_year - min_year + 1)) as number
        )
        UNION ALL
        SELECT toStartOfWeek(toDate(concat(toString(year), '-07-01'))) as week_date
        FROM (
            SELECT min_year + number as year
            FROM date_range
            ARRAY JOIN range(0, toUInt32(max_year - min_year + 1)) as number
        )
    )
    ORDER BY week_date
)
SELECT
    wd.week_date as snapshot_timestamp,
    'weekly' as snapshot_type,
    hp.wh_id,
    hp.hu_code,
    hp.sku_code,
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
    argMax(hp.latest_hu_event_id, hp.hour_window) as latest_hu_event_id,
    argMax(hp.latest_quant_event_id, hp.hour_window) as latest_quant_event_id,
    max(hp.last_event_time) as last_event_time,
    -- Latest values for all other fields
    argMax(hp.hu_event_seq, hp.hour_window) as hu_event_seq,
    argMax(hp.hu_id, hp.hour_window) as hu_id,
    argMax(hp.hu_event_type, hp.hour_window) as hu_event_type,
    argMax(hp.hu_event_payload, hp.hour_window) as hu_event_payload,
    argMax(hp.hu_event_attrs, hp.hour_window) as hu_event_attrs,
    argMax(hp.session_id, hp.hour_window) as session_id,
    argMax(hp.task_id, hp.hour_window) as task_id,
    argMax(hp.correlation_id, hp.hour_window) as correlation_id,
    argMax(hp.storage_id, hp.hour_window) as storage_id,
    argMax(hp.outer_hu_id, hp.hour_window) as outer_hu_id,
    argMax(hp.effective_storage_id, hp.hour_window) as effective_storage_id,
    argMax(hp.sku_id, hp.hour_window) as sku_id,
    argMax(hp.hu_kind_id, hp.hour_window) as hu_kind_id,
    argMax(hp.hu_state, hp.hour_window) as hu_state,
    argMax(hp.hu_attrs, hp.hour_window) as hu_attrs,
    argMax(hp.hu_created_at, hp.hour_window) as hu_created_at,
    argMax(hp.hu_updated_at, hp.hour_window) as hu_updated_at,
    argMax(hp.hu_lock_task_id, hp.hour_window) as hu_lock_task_id,
    argMax(hp.hu_effective_storage_id, hp.hour_window) as hu_effective_storage_id,
    argMax(hp.hu_kind_code, hp.hour_window) as hu_kind_code,
    argMax(hp.hu_kind_name, hp.hour_window) as hu_kind_name,
    argMax(hp.hu_kind_attrs, hp.hour_window) as hu_kind_attrs,
    argMax(hp.hu_kind_active, hp.hour_window) as hu_kind_active,
    argMax(hp.hu_kind_max_volume, hp.hour_window) as hu_kind_max_volume,
    argMax(hp.hu_kind_max_weight, hp.hour_window) as hu_kind_max_weight,
    argMax(hp.hu_kind_usage_type, hp.hour_window) as hu_kind_usage_type,
    argMax(hp.hu_kind_abbr, hp.hour_window) as hu_kind_abbr,
    argMax(hp.hu_kind_length, hp.hour_window) as hu_kind_length,
    argMax(hp.hu_kind_breadth, hp.hour_window) as hu_kind_breadth,
    argMax(hp.hu_kind_height, hp.hour_window) as hu_kind_height,
    argMax(hp.hu_kind_weight, hp.hour_window) as hu_kind_weight,
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
    argMax(hp.storage_bin_type_active, hp.hour_window) as storage_bin_type_active,
    argMax(hp.storage_zone_id, hp.hour_window) as storage_zone_id,
    argMax(hp.storage_zone_code, hp.hour_window) as storage_zone_code,
    argMax(hp.storage_zone_description, hp.hour_window) as storage_zone_description,
    argMax(hp.storage_zone_face, hp.hour_window) as storage_zone_face,
    argMax(hp.storage_peripheral, hp.hour_window) as storage_peripheral,
    argMax(hp.storage_surveillance_config, hp.hour_window) as storage_surveillance_config,
    argMax(hp.storage_zone_active, hp.hour_window) as storage_zone_active,
    argMax(hp.storage_area_id, hp.hour_window) as storage_area_id,
    argMax(hp.storage_area_code, hp.hour_window) as storage_area_code,
    argMax(hp.storage_area_description, hp.hour_window) as storage_area_description,
    argMax(hp.storage_area_type, hp.hour_window) as storage_area_type,
    argMax(hp.storage_rolling_days, hp.hour_window) as storage_rolling_days,
    argMax(hp.storage_area_active, hp.hour_window) as storage_area_active,
    argMax(hp.storage_x1, hp.hour_window) as storage_x1,
    argMax(hp.storage_x2, hp.hour_window) as storage_x2,
    argMax(hp.storage_y1, hp.hour_window) as storage_y1,
    argMax(hp.storage_y2, hp.hour_window) as storage_y2,
    argMax(hp.storage_position_active, hp.hour_window) as storage_position_active,
    argMax(hp.storage_attrs, hp.hour_window) as storage_attrs,
    argMax(hp.storage_bin_mapping, hp.hour_window) as storage_bin_mapping,
    argMax(hp.storage_created_at, hp.hour_window) as storage_created_at,
    argMax(hp.storage_updated_at, hp.hour_window) as storage_updated_at,
    argMax(hp.sku_name, hp.hour_window) as sku_name,
    argMax(hp.sku_short_description, hp.hour_window) as sku_short_description,
    argMax(hp.sku_description, hp.hour_window) as sku_description,
    argMax(hp.sku_category, hp.hour_window) as sku_category,
    argMax(hp.sku_product, hp.hour_window) as sku_product,
    argMax(hp.sku_product_id, hp.hour_window) as sku_product_id,
    argMax(hp.sku_category_group, hp.hour_window) as sku_category_group,
    argMax(hp.sku_sub_brand, hp.hour_window) as sku_sub_brand,
    argMax(hp.sku_brand, hp.hour_window) as sku_brand,
    argMax(hp.sku_fulfillment_type, hp.hour_window) as sku_fulfillment_type,
    argMax(hp.sku_inventory_type, hp.hour_window) as sku_inventory_type,
    argMax(hp.sku_shelf_life, hp.hour_window) as sku_shelf_life,
    argMax(hp.sku_handling_unit_type, hp.hour_window) as sku_handling_unit_type,
    argMax(hp.sku_cases_per_layer, hp.hour_window) as sku_cases_per_layer,
    argMax(hp.sku_layers, hp.hour_window) as sku_layers,
    argMax(hp.sku_active_from, hp.hour_window) as sku_active_from,
    argMax(hp.sku_active_till, hp.hour_window) as sku_active_till,
    argMax(hp.sku_l0_units, hp.hour_window) as sku_l0_units,
    argMax(hp.sku_l0_name, hp.hour_window) as sku_l0_name,
    argMax(hp.sku_l0_weight, hp.hour_window) as sku_l0_weight,
    argMax(hp.sku_l0_volume, hp.hour_window) as sku_l0_volume,
    argMax(hp.sku_l0_length, hp.hour_window) as sku_l0_length,
    argMax(hp.sku_l0_width, hp.hour_window) as sku_l0_width,
    argMax(hp.sku_l0_height, hp.hour_window) as sku_l0_height,
    argMax(hp.sku_l1_units, hp.hour_window) as sku_l1_units,
    argMax(hp.sku_l1_name, hp.hour_window) as sku_l1_name,
    argMax(hp.sku_l1_weight, hp.hour_window) as sku_l1_weight,
    argMax(hp.sku_l1_volume, hp.hour_window) as sku_l1_volume,
    argMax(hp.sku_l1_length, hp.hour_window) as sku_l1_length,
    argMax(hp.sku_l1_width, hp.hour_window) as sku_l1_width,
    argMax(hp.sku_l1_height, hp.hour_window) as sku_l1_height,
    argMax(hp.sku_active, hp.hour_window) as sku_active,
    argMax(hp.sku_created_at, hp.hour_window) as sku_created_at,
    argMax(hp.sku_updated_at, hp.hour_window) as sku_updated_at,
    argMax(hp.effective_storage_bin_code, hp.hour_window) as effective_storage_bin_code,
    argMax(hp.effective_storage_bin_description, hp.hour_window) as effective_storage_bin_description,
    argMax(hp.effective_storage_bin_status, hp.hour_window) as effective_storage_bin_status,
    argMax(hp.effective_storage_bin_hu_id, hp.hour_window) as effective_storage_bin_hu_id,
    argMax(hp.effective_storage_multi_sku, hp.hour_window) as effective_storage_multi_sku,
    argMax(hp.effective_storage_multi_batch, hp.hour_window) as effective_storage_multi_batch,
    argMax(hp.effective_storage_picking_position, hp.hour_window) as effective_storage_picking_position,
    argMax(hp.effective_storage_putaway_position, hp.hour_window) as effective_storage_putaway_position,
    argMax(hp.effective_storage_rank, hp.hour_window) as effective_storage_rank,
    argMax(hp.effective_storage_aisle, hp.hour_window) as effective_storage_aisle,
    argMax(hp.effective_storage_bay, hp.hour_window) as effective_storage_bay,
    argMax(hp.effective_storage_level, hp.hour_window) as effective_storage_level,
    argMax(hp.effective_storage_position, hp.hour_window) as effective_storage_position,
    argMax(hp.effective_storage_depth, hp.hour_window) as effective_storage_depth,
    argMax(hp.effective_storage_max_sku_count, hp.hour_window) as effective_storage_max_sku_count,
    argMax(hp.effective_storage_max_sku_batch_count, hp.hour_window) as effective_storage_max_sku_batch_count,
    argMax(hp.effective_storage_bin_type_id, hp.hour_window) as effective_storage_bin_type_id,
    argMax(hp.effective_storage_bin_type_code, hp.hour_window) as effective_storage_bin_type_code,
    argMax(hp.effective_storage_bin_type_description, hp.hour_window) as effective_storage_bin_type_description,
    argMax(hp.effective_storage_max_volume_in_cc, hp.hour_window) as effective_storage_max_volume_in_cc,
    argMax(hp.effective_storage_max_weight_in_kg, hp.hour_window) as effective_storage_max_weight_in_kg,
    argMax(hp.effective_storage_pallet_capacity, hp.hour_window) as effective_storage_pallet_capacity,
    argMax(hp.effective_storage_hu_type, hp.hour_window) as effective_storage_hu_type,
    argMax(hp.effective_storage_auxiliary_bin, hp.hour_window) as effective_storage_auxiliary_bin,
    argMax(hp.effective_storage_hu_multi_sku, hp.hour_window) as effective_storage_hu_multi_sku,
    argMax(hp.effective_storage_hu_multi_batch, hp.hour_window) as effective_storage_hu_multi_batch,
    argMax(hp.effective_storage_use_derived_pallet_best_fit, hp.hour_window) as effective_storage_use_derived_pallet_best_fit,
    argMax(hp.effective_storage_only_full_pallet, hp.hour_window) as effective_storage_only_full_pallet,
    argMax(hp.effective_storage_bin_type_active, hp.hour_window) as effective_storage_bin_type_active,
    argMax(hp.effective_storage_zone_id, hp.hour_window) as effective_storage_zone_id,
    argMax(hp.effective_storage_zone_code, hp.hour_window) as effective_storage_zone_code,
    argMax(hp.effective_storage_zone_description, hp.hour_window) as effective_storage_zone_description,
    argMax(hp.effective_storage_zone_face, hp.hour_window) as effective_storage_zone_face,
    argMax(hp.effective_storage_peripheral, hp.hour_window) as effective_storage_peripheral,
    argMax(hp.effective_storage_surveillance_config, hp.hour_window) as effective_storage_surveillance_config,
    argMax(hp.effective_storage_zone_active, hp.hour_window) as effective_storage_zone_active,
    argMax(hp.effective_storage_area_id, hp.hour_window) as effective_storage_area_id,
    argMax(hp.effective_storage_area_code, hp.hour_window) as effective_storage_area_code,
    argMax(hp.effective_storage_area_description, hp.hour_window) as effective_storage_area_description,
    argMax(hp.effective_storage_area_type, hp.hour_window) as effective_storage_area_type,
    argMax(hp.effective_storage_rolling_days, hp.hour_window) as effective_storage_rolling_days,
    argMax(hp.effective_storage_area_active, hp.hour_window) as effective_storage_area_active,
    argMax(hp.effective_storage_x1, hp.hour_window) as effective_storage_x1,
    argMax(hp.effective_storage_x2, hp.hour_window) as effective_storage_x2,
    argMax(hp.effective_storage_y1, hp.hour_window) as effective_storage_y1,
    argMax(hp.effective_storage_y2, hp.hour_window) as effective_storage_y2,
    argMax(hp.effective_storage_position_active, hp.hour_window) as effective_storage_position_active,
    argMax(hp.effective_storage_attrs, hp.hour_window) as effective_storage_attrs,
    argMax(hp.effective_storage_bin_mapping, hp.hour_window) as effective_storage_bin_mapping,
    argMax(hp.effective_storage_created_at, hp.hour_window) as effective_storage_created_at,
    argMax(hp.effective_storage_updated_at, hp.hour_window) as effective_storage_updated_at,
    argMax(hp.outer_hu_code, hp.hour_window) as outer_hu_code,
    argMax(hp.outer_hu_kind_id, hp.hour_window) as outer_hu_kind_id,
    argMax(hp.outer_hu_session_id, hp.hour_window) as outer_hu_session_id,
    argMax(hp.outer_hu_task_id, hp.hour_window) as outer_hu_task_id,
    argMax(hp.outer_hu_storage_id, hp.hour_window) as outer_hu_storage_id,
    argMax(hp.outer_hu_outer_hu_id, hp.hour_window) as outer_hu_outer_hu_id,
    argMax(hp.outer_hu_state, hp.hour_window) as outer_hu_state,
    argMax(hp.outer_hu_attrs, hp.hour_window) as outer_hu_attrs,
    argMax(hp.outer_hu_created_at, hp.hour_window) as outer_hu_created_at,
    argMax(hp.outer_hu_updated_at, hp.hour_window) as outer_hu_updated_at,
    argMax(hp.outer_hu_lock_task_id, hp.hour_window) as outer_hu_lock_task_id,
    argMax(hp.outer_hu_effective_storage_id, hp.hour_window) as outer_hu_effective_storage_id,
    argMax(hp.outer_hu_kind_code, hp.hour_window) as outer_hu_kind_code,
    argMax(hp.outer_hu_kind_name, hp.hour_window) as outer_hu_kind_name,
    argMax(hp.outer_hu_kind_attrs, hp.hour_window) as outer_hu_kind_attrs,
    argMax(hp.outer_hu_kind_active, hp.hour_window) as outer_hu_kind_active,
    argMax(hp.outer_hu_kind_max_volume, hp.hour_window) as outer_hu_kind_max_volume,
    argMax(hp.outer_hu_kind_max_weight, hp.hour_window) as outer_hu_kind_max_weight,
    argMax(hp.outer_hu_kind_usage_type, hp.hour_window) as outer_hu_kind_usage_type,
    argMax(hp.outer_hu_kind_abbr, hp.hour_window) as outer_hu_kind_abbr,
    argMax(hp.outer_hu_kind_length, hp.hour_window) as outer_hu_kind_length,
    argMax(hp.outer_hu_kind_breadth, hp.hour_window) as outer_hu_kind_breadth,
    argMax(hp.outer_hu_kind_height, hp.hour_window) as outer_hu_kind_height,
    argMax(hp.outer_hu_kind_weight, hp.hour_window) as outer_hu_kind_weight,
    now() as _snapshot_generated_at,
    now64(3) as _processed_at
FROM week_dates wd
CROSS JOIN wms_inventory_hourly_position hp
WHERE hp.hour_window < wd.week_date
GROUP BY wd.week_date, hp.wh_id, hp.hu_code, hp.sku_code, hp.uom, hp.bucket, hp.batch, hp.price, hp.inclusion_status, hp.locked_by_task_id, hp.lock_mode
HAVING cumulative_qty != 0
SETTINGS 
    max_memory_usage = 10000000000,  -- 10GB limit
    max_bytes_before_external_group_by = 5000000000,  -- Use disk for GROUP BY after 5GB
    distributed_aggregation_memory_efficient = 1,  -- Use memory-efficient aggregation
    max_threads = 4;  -- Limit parallelism to reduce memory pressure

-- Note: To avoid duplicates, you may want to clear the table first:
-- TRUNCATE TABLE wms_inventory_weekly_snapshot;
-- Or delete specific weeks:
-- ALTER TABLE wms_inventory_weekly_snapshot DELETE WHERE snapshot_timestamp >= '2024-01-01';