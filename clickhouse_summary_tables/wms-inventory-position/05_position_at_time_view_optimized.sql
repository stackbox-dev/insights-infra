-- Optimized parameterized view for WMS inventory position at a specific point in time
-- Performance optimizations:
-- 1. Use LEFT JOINs instead of FULL OUTER JOINs
-- 2. Start from hourly data (most common case) and add snapshot/current hour if available
-- 3. Reduce CROSS JOINs by extracting parameters once
-- 4. Simplify JOIN conditions

DROP VIEW IF EXISTS wms_inventory_position_at_time;

CREATE VIEW wms_inventory_position_at_time AS
WITH 
-- Extract parameters once
param_wh_id AS (SELECT {wh_id:UInt64} as value),
param_target_time AS (SELECT {target_time:DateTime64(3)} as value),
target_hour AS (SELECT toStartOfHour((SELECT value FROM param_target_time)) as value),

-- Find the most recent weekly snapshot (if exists)
latest_snapshot_date AS (
    SELECT max(snapshot_timestamp) as snapshot_ts
    FROM wms_inventory_weekly_snapshot
    WHERE wh_id = (SELECT value FROM param_wh_id)
      AND snapshot_timestamp <= (SELECT value FROM param_target_time)
),

-- Get all inventory positions from the base hourly data
-- This is our primary source, always present
base_positions AS (
    SELECT 
        wh_id,
        hu_code,
        sku_code,
        uom,
        bucket,
        batch,
        price,
        inclusion_status,
        locked_by_task_id,
        lock_mode,
        sum(hourly_qty_change) as total_qty,
        sum(event_count) as total_events,
        argMax(latest_hu_event_id, hour_window) as latest_hu_event_id,
        argMax(latest_quant_event_id, hour_window) as latest_quant_event_id,
        max(last_event_time) as last_update_time,
        -- Latest dimensional data
        argMax(hu_event_seq, hour_window) as hu_event_seq,
        argMax(hu_id, hour_window) as hu_id,
        argMax(hu_event_type, hour_window) as hu_event_type,
        argMax(session_id, hour_window) as session_id,
        argMax(task_id, hour_window) as task_id,
        argMax(correlation_id, hour_window) as correlation_id,
        argMax(storage_id, hour_window) as storage_id,
        argMax(outer_hu_id, hour_window) as outer_hu_id,
        argMax(effective_storage_id, hour_window) as effective_storage_id,
        argMax(sku_id, hour_window) as sku_id,
        argMax(hu_kind_id, hour_window) as hu_kind_id,
        argMax(hu_state, hour_window) as hu_state,
        argMax(hu_attrs, hour_window) as hu_attrs,
        argMax(hu_created_at, hour_window) as hu_created_at,
        argMax(hu_updated_at, hour_window) as hu_updated_at,
        argMax(hu_lock_task_id, hour_window) as hu_lock_task_id,
        argMax(hu_effective_storage_id, hour_window) as hu_effective_storage_id,
        argMax(hu_kind_code, hour_window) as hu_kind_code,
        argMax(hu_kind_name, hour_window) as hu_kind_name,
        argMax(storage_bin_code, hour_window) as storage_bin_code,
        argMax(storage_bin_description, hour_window) as storage_bin_description,
        argMax(storage_bin_status, hour_window) as storage_bin_status,
        argMax(storage_aisle, hour_window) as storage_aisle,
        argMax(storage_bay, hour_window) as storage_bay,
        argMax(storage_level, hour_window) as storage_level,
        argMax(storage_position, hour_window) as storage_position,
        argMax(storage_area_code, hour_window) as storage_area_code,
        argMax(storage_area_description, hour_window) as storage_area_description,
        argMax(storage_zone_code, hour_window) as storage_zone_code,
        argMax(storage_zone_description, hour_window) as storage_zone_description,
        argMax(sku_name, hour_window) as sku_name,
        argMax(sku_category, hour_window) as sku_category,
        argMax(sku_brand, hour_window) as sku_brand,
        argMax(sku_fulfillment_type, hour_window) as sku_fulfillment_type
    FROM wms_inventory_hourly_position
    WHERE wh_id = (SELECT value FROM param_wh_id)
      AND hour_window < (SELECT value FROM target_hour)
    GROUP BY 
        wh_id, hu_code, sku_code, uom, bucket, batch, 
        price, inclusion_status, locked_by_task_id, lock_mode
),

-- Get current hour events (if we're querying for current time)
current_hour_data AS (
    SELECT 
        wh_id,
        hu_code,
        sku_code,
        uom,
        bucket,
        batch,
        price,
        inclusion_status,
        locked_by_task_id,
        lock_mode,
        sum(qty_added) as current_hour_qty,
        count() as current_hour_events
    FROM wms_inventory_events_enriched FINAL
    WHERE wh_id = (SELECT value FROM param_wh_id)
      AND hu_event_timestamp >= (SELECT value FROM target_hour)
      AND hu_event_timestamp <= (SELECT value FROM param_target_time)
    GROUP BY 
        wh_id, hu_code, sku_code, uom, bucket, batch,
        price, inclusion_status, locked_by_task_id, lock_mode
)

-- Final result combining all sources
SELECT 
    bp.wh_id,
    bp.hu_code,
    bp.sku_code,
    bp.uom,
    bp.bucket,
    bp.batch,
    bp.price,
    bp.inclusion_status,
    bp.locked_by_task_id,
    bp.lock_mode,
    -- Calculate final quantity
    bp.total_qty + COALESCE(ch.current_hour_qty, 0) as quantity,
    bp.total_events + COALESCE(ch.current_hour_events, 0) as total_events,
    -- Latest event IDs
    bp.latest_hu_event_id,
    bp.latest_quant_event_id,
    -- Dimensional data
    bp.hu_event_seq,
    bp.hu_id,
    bp.hu_event_type,
    bp.session_id,
    bp.task_id,
    bp.correlation_id,
    bp.storage_id,
    bp.outer_hu_id,
    bp.effective_storage_id,
    bp.sku_id,
    bp.hu_kind_id,
    bp.hu_state,
    bp.hu_attrs,
    bp.hu_created_at,
    bp.hu_updated_at,
    bp.hu_lock_task_id,
    bp.hu_effective_storage_id,
    bp.hu_kind_code,
    bp.hu_kind_name,
    bp.storage_bin_code,
    bp.storage_bin_description,
    bp.storage_bin_status,
    bp.storage_aisle,
    bp.storage_bay,
    bp.storage_level,
    bp.storage_position,
    bp.storage_area_code,
    bp.storage_area_description,
    bp.storage_zone_code,
    bp.storage_zone_description,
    bp.sku_name,
    bp.sku_category,
    bp.sku_brand,
    bp.sku_fulfillment_type,
    bp.last_update_time,
    (SELECT value FROM param_target_time) as query_time
FROM base_positions bp
LEFT JOIN current_hour_data ch
    USING (wh_id, hu_code, sku_code, uom, bucket, batch, price, inclusion_status, locked_by_task_id, lock_mode)
WHERE bp.total_qty + COALESCE(ch.current_hour_qty, 0) != 0;

-- Alternative: Simpler version that only uses hourly data (fastest)
DROP VIEW IF EXISTS wms_inventory_position_at_time_simple;

CREATE VIEW wms_inventory_position_at_time_simple AS
WITH 
param_wh_id AS (SELECT {wh_id:UInt64} as value),
param_target_time AS (SELECT {target_time:DateTime64(3)} as value)
SELECT 
    wh_id,
    hu_code,
    sku_code,
    uom,
    bucket,
    batch,
    price,
    inclusion_status,
    locked_by_task_id,
    lock_mode,
    sum(hourly_qty_change) as quantity,
    sum(event_count) as total_events,
    argMax(latest_hu_event_id, hour_window) as latest_hu_event_id,
    argMax(latest_quant_event_id, hour_window) as latest_quant_event_id,
    max(last_event_time) as last_update_time,
    argMax(storage_bin_code, hour_window) as storage_bin_code,
    argMax(storage_zone_code, hour_window) as storage_zone_code,
    argMax(sku_name, hour_window) as sku_name,
    argMax(sku_brand, hour_window) as sku_brand,
    (SELECT value FROM param_target_time) as query_time
FROM wms_inventory_hourly_position
WHERE wh_id = (SELECT value FROM param_wh_id)
  AND hour_window <= toStartOfHour((SELECT value FROM param_target_time))
GROUP BY 
    wh_id, hu_code, sku_code, uom, bucket, batch, 
    price, inclusion_status, locked_by_task_id, lock_mode
HAVING quantity != 0;