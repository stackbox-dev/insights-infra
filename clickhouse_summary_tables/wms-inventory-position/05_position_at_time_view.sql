-- Optimized parameterized view using UNION ALL approach for 3-tier architecture
-- Much simpler and more performant than complex JOINs
-- Handles new SKUs naturally and avoids NULL issues with dimensional data

DROP VIEW IF EXISTS wms_inventory_position_at_time;

CREATE VIEW wms_inventory_position_at_time AS
WITH 
-- Parameters
param_wh_id AS (SELECT {wh_id:UInt64} as value),
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
        cumulative_qty as qty_change,
        snapshot_timestamp as event_time,
        latest_hu_event_id,
        latest_quant_event_id,
        storage_bin_code,
        storage_bin_description,
        storage_bin_status,
        storage_aisle,
        storage_bay,
        storage_level,
        storage_position,
        storage_area_code,
        storage_area_description,
        storage_zone_code,
        storage_zone_description,
        sku_name,
        sku_category,
        sku_brand,
        sku_fulfillment_type,
        hu_event_seq,
        hu_id,
        hu_event_type,
        session_id,
        task_id,
        correlation_id,
        storage_id,
        outer_hu_id,
        effective_storage_id,
        sku_id,
        hu_kind_id,
        hu_state,
        hu_attrs,
        hu_created_at,
        hu_updated_at,
        hu_lock_task_id,
        hu_effective_storage_id,
        hu_kind_code,
        hu_kind_name
    FROM wms_inventory_weekly_snapshot
    WHERE wh_id = (SELECT value FROM param_wh_id)
      AND snapshot_timestamp = (SELECT value FROM latest_snapshot_time)
      AND (SELECT value FROM latest_snapshot_time) != toDateTime('1970-01-01')  -- Only if snapshot exists
    
    UNION ALL
    
    -- 2. Hourly position changes (between snapshot and current hour)
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
        hourly_qty_change as qty_change,
        hour_window as event_time,
        latest_hu_event_id,
        latest_quant_event_id,
        storage_bin_code,
        storage_bin_description,
        storage_bin_status,
        storage_aisle,
        storage_bay,
        storage_level,
        storage_position,
        storage_area_code,
        storage_area_description,
        storage_zone_code,
        storage_zone_description,
        sku_name,
        sku_category,
        sku_brand,
        sku_fulfillment_type,
        hu_event_seq,
        hu_id,
        hu_event_type,
        session_id,
        task_id,
        correlation_id,
        storage_id,
        outer_hu_id,
        effective_storage_id,
        sku_id,
        hu_kind_id,
        hu_state,
        hu_attrs,
        hu_created_at,
        hu_updated_at,
        hu_lock_task_id,
        hu_effective_storage_id,
        hu_kind_code,
        hu_kind_name
    FROM wms_inventory_hourly_position
    WHERE wh_id = (SELECT value FROM param_wh_id)
      AND hour_window > (SELECT value FROM latest_snapshot_time)
      AND hour_window < (SELECT value FROM target_hour)
    
    UNION ALL
    
    -- 3. Current hour events (raw events with FINAL for deduplication)
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
        qty_added as qty_change,
        hu_event_timestamp as event_time,
        hu_event_id as latest_hu_event_id,
        quant_event_id as latest_quant_event_id,
        storage_bin_code,
        storage_bin_description,
        storage_bin_status,
        storage_aisle,
        storage_bay,
        storage_level,
        storage_position,
        storage_area_code,
        storage_area_description,
        storage_zone_code,
        storage_zone_description,
        sku_name,
        sku_category,
        sku_brand,
        sku_fulfillment_type,
        hu_event_seq,
        hu_id,
        hu_event_type,
        session_id,
        task_id,
        correlation_id,
        storage_id,
        outer_hu_id,
        effective_storage_id,
        sku_id,
        hu_kind_id,
        hu_state,
        hu_attrs,
        hu_created_at,
        hu_updated_at,
        hu_lock_task_id,
        hu_effective_storage_id,
        hu_kind_code,
        hu_kind_name
    FROM wms_inventory_events_enriched FINAL
    WHERE wh_id = (SELECT value FROM param_wh_id)
      AND hu_event_timestamp >= (SELECT value FROM target_hour)
      AND hu_event_timestamp <= (SELECT value FROM param_target_time)
)

-- Final aggregation to combine all sources
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
    sum(qty_change) as quantity,
    count() as total_events,
    argMax(latest_hu_event_id, event_time) as latest_hu_event_id,
    argMax(latest_quant_event_id, event_time) as latest_quant_event_id,
    max(event_time) as last_update_time,
    -- Take latest dimensional data based on event time
    argMax(storage_bin_code, event_time) as storage_bin_code,
    argMax(storage_bin_description, event_time) as storage_bin_description,
    argMax(storage_bin_status, event_time) as storage_bin_status,
    argMax(storage_aisle, event_time) as storage_aisle,
    argMax(storage_bay, event_time) as storage_bay,
    argMax(storage_level, event_time) as storage_level,
    argMax(storage_position, event_time) as storage_position,
    argMax(storage_area_code, event_time) as storage_area_code,
    argMax(storage_area_description, event_time) as storage_area_description,
    argMax(storage_zone_code, event_time) as storage_zone_code,
    argMax(storage_zone_description, event_time) as storage_zone_description,
    argMax(sku_name, event_time) as sku_name,
    argMax(sku_category, event_time) as sku_category,
    argMax(sku_brand, event_time) as sku_brand,
    argMax(sku_fulfillment_type, event_time) as sku_fulfillment_type,
    argMax(hu_event_seq, event_time) as hu_event_seq,
    argMax(hu_id, event_time) as hu_id,
    argMax(hu_event_type, event_time) as hu_event_type,
    argMax(session_id, event_time) as session_id,
    argMax(task_id, event_time) as task_id,
    argMax(correlation_id, event_time) as correlation_id,
    argMax(storage_id, event_time) as storage_id,
    argMax(outer_hu_id, event_time) as outer_hu_id,
    argMax(effective_storage_id, event_time) as effective_storage_id,
    argMax(sku_id, event_time) as sku_id,
    argMax(hu_kind_id, event_time) as hu_kind_id,
    argMax(hu_state, event_time) as hu_state,
    argMax(hu_attrs, event_time) as hu_attrs,
    argMax(hu_created_at, event_time) as hu_created_at,
    argMax(hu_updated_at, event_time) as hu_updated_at,
    argMax(hu_lock_task_id, event_time) as hu_lock_task_id,
    argMax(hu_effective_storage_id, event_time) as hu_effective_storage_id,
    argMax(hu_kind_code, event_time) as hu_kind_code,
    argMax(hu_kind_name, event_time) as hu_kind_name,
    (SELECT value FROM param_target_time) as query_time,
    (SELECT value FROM latest_snapshot_time) as base_snapshot_time
FROM all_positions
GROUP BY 
    wh_id,
    hu_code,
    sku_code,
    uom,
    bucket,
    batch,
    price,
    inclusion_status,
    locked_by_task_id,
    lock_mode
HAVING quantity != 0
ORDER BY hu_code, sku_code;