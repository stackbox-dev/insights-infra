-- Parameterized view for WMS inventory position at a specific point in time
-- Uses ClickHouse parameterized views feature (requires ClickHouse 23.1+)
-- Documentation: https://clickhouse.com/docs/sql-reference/statements/create/view#parameterized-view
--
-- Usage examples:
-- SELECT * FROM wms_inventory_position_at_time(wh_id=1, target_time='2025-08-08 14:30:00')
-- SELECT * FROM wms_inventory_position_at_time(wh_id=1, target_time=now())
-- SELECT * FROM wms_inventory_position_at_time(wh_id=1, target_time='2025-08-08 14:30:00') WHERE sku_code = 'SKU123'

DROP VIEW IF EXISTS wms_inventory_position_at_time;

CREATE VIEW wms_inventory_position_at_time AS
WITH 
-- Parameters with defaults
params AS (
    SELECT 
        {wh_id:UInt64} as param_wh_id,
        {target_time:DateTime64(3)} as param_target_time
),
-- Calculate the hour window for the target time
target_hour AS (
    SELECT 
        param_wh_id as wh_id,
        param_target_time as target_time,
        toStartOfHour(param_target_time) as hour_start
    FROM params
),
-- Get cumulative position from hourly snapshots up to (but not including) the target hour
hourly_position AS (
    SELECT 
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
        sum(hp.hourly_qty_change) as cumulative_qty_from_hourly,
        max(hp.hour_window) as last_hour_window,
        argMax(hp.latest_hu_event_id, hp.hour_window) as latest_hu_event_id,
        argMax(hp.latest_quant_event_id, hp.hour_window) as latest_quant_event_id,
        argMax(hp.hu_event_seq, hp.hour_window) as hu_event_seq,
        argMax(hp.hu_id, hp.hour_window) as hu_id,
        argMax(hp.hu_event_type, hp.hour_window) as hu_event_type,
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
        argMax(hp.storage_bin_code, hp.hour_window) as storage_bin_code,
        argMax(hp.storage_bin_description, hp.hour_window) as storage_bin_description,
        argMax(hp.storage_bin_status, hp.hour_window) as storage_bin_status,
        argMax(hp.storage_aisle, hp.hour_window) as storage_aisle,
        argMax(hp.storage_bay, hp.hour_window) as storage_bay,
        argMax(hp.storage_level, hp.hour_window) as storage_level,
        argMax(hp.storage_position, hp.hour_window) as storage_position,
        argMax(hp.storage_area_code, hp.hour_window) as storage_area_code,
        argMax(hp.storage_area_description, hp.hour_window) as storage_area_description,
        argMax(hp.storage_zone_code, hp.hour_window) as storage_zone_code,
        argMax(hp.storage_zone_description, hp.hour_window) as storage_zone_description,
        argMax(hp.sku_name, hp.hour_window) as sku_name,
        argMax(hp.sku_category, hp.hour_window) as sku_category,
        argMax(hp.sku_brand, hp.hour_window) as sku_brand,
        argMax(hp.sku_fulfillment_type, hp.hour_window) as sku_fulfillment_type
    FROM wms_inventory_hourly_position hp
    CROSS JOIN target_hour th
    WHERE hp.wh_id = th.wh_id
      AND hp.hour_window < th.hour_start
    GROUP BY 
        hp.wh_id,
        hp.hu_code,
        hp.sku_code,
        hp.uom,
        hp.bucket,
        hp.batch,
        hp.price,
        hp.inclusion_status,
        hp.locked_by_task_id,
        hp.lock_mode
),
-- Get incremental events from the target hour up to the exact target time
incremental_events AS (
    SELECT 
        e.wh_id,
        e.hu_code,
        e.sku_code as sku_code,
        e.uom,
        e.bucket,
        e.batch,
        e.price,
        e.inclusion_status,
        e.locked_by_task_id,
        e.lock_mode,
        sum(e.qty_added) as incremental_qty,
        argMax(e.hu_event_id, e.hu_event_timestamp) as latest_hu_event_id,
        argMax(e.quant_event_id, e.hu_event_timestamp) as latest_quant_event_id,
        argMax(e.hu_event_seq, e.hu_event_timestamp) as hu_event_seq,
        argMax(e.hu_id, e.hu_event_timestamp) as hu_id,
        argMax(e.hu_event_type, e.hu_event_timestamp) as hu_event_type,
        argMax(e.session_id, e.hu_event_timestamp) as session_id,
        argMax(e.task_id, e.hu_event_timestamp) as task_id,
        argMax(e.correlation_id, e.hu_event_timestamp) as correlation_id,
        argMax(e.storage_id, e.hu_event_timestamp) as storage_id,
        argMax(e.outer_hu_id, e.hu_event_timestamp) as outer_hu_id,
        argMax(e.effective_storage_id, e.hu_event_timestamp) as effective_storage_id,
        argMax(e.sku_id, e.hu_event_timestamp) as sku_id,
        argMax(e.hu_kind_id, e.hu_event_timestamp) as hu_kind_id,
        argMax(e.hu_state, e.hu_event_timestamp) as hu_state,
        argMax(e.hu_attrs, e.hu_event_timestamp) as hu_attrs,
        argMax(e.hu_created_at, e.hu_event_timestamp) as hu_created_at,
        argMax(e.hu_updated_at, e.hu_event_timestamp) as hu_updated_at,
        argMax(e.hu_lock_task_id, e.hu_event_timestamp) as hu_lock_task_id,
        argMax(e.hu_effective_storage_id, e.hu_event_timestamp) as hu_effective_storage_id,
        argMax(e.hu_kind_code, e.hu_event_timestamp) as hu_kind_code,
        argMax(e.hu_kind_name, e.hu_event_timestamp) as hu_kind_name,
        argMax(e.storage_bin_code, e.hu_event_timestamp) as storage_bin_code,
        argMax(e.storage_bin_description, e.hu_event_timestamp) as storage_bin_description,
        argMax(e.storage_bin_status, e.hu_event_timestamp) as storage_bin_status,
        argMax(e.storage_aisle, e.hu_event_timestamp) as storage_aisle,
        argMax(e.storage_bay, e.hu_event_timestamp) as storage_bay,
        argMax(e.storage_level, e.hu_event_timestamp) as storage_level,
        argMax(e.storage_position, e.hu_event_timestamp) as storage_position,
        argMax(e.storage_area_code, e.hu_event_timestamp) as storage_area_code,
        argMax(e.storage_area_description, e.hu_event_timestamp) as storage_area_description,
        argMax(e.storage_zone_code, e.hu_event_timestamp) as storage_zone_code,
        argMax(e.storage_zone_description, e.hu_event_timestamp) as storage_zone_description,
        argMax(e.sku_name, e.hu_event_timestamp) as sku_name,
        argMax(e.sku_category, e.hu_event_timestamp) as sku_category,
        argMax(e.sku_brand, e.hu_event_timestamp) as sku_brand,
        argMax(e.sku_fulfillment_type, e.hu_event_timestamp) as sku_fulfillment_type,
        max(e.hu_event_timestamp) as last_event_time
    FROM wms_inventory_events_enriched e
    CROSS JOIN target_hour th
    WHERE e.wh_id = th.wh_id
      AND e.hu_event_timestamp >= th.hour_start
      AND e.hu_event_timestamp <= th.target_time
    GROUP BY 
        e.wh_id,
        e.hu_code,
        e.sku_code,
        e.uom,
        e.bucket,
        e.batch,
        e.price,
        e.inclusion_status,
        e.locked_by_task_id,
        e.lock_mode
)
-- Combine hourly and incremental data to get final position
SELECT 
    coalesce(hp.wh_id, ie.wh_id) as wh_id,
    coalesce(hp.hu_code, ie.hu_code) as hu_code,
    coalesce(hp.sku_code, ie.sku_code) as sku_code,
    coalesce(hp.uom, ie.uom) as uom,
    coalesce(hp.bucket, ie.bucket) as bucket,
    coalesce(hp.batch, ie.batch) as batch,
    coalesce(hp.price, ie.price) as price,
    coalesce(hp.inclusion_status, ie.inclusion_status) as inclusion_status,
    coalesce(hp.locked_by_task_id, ie.locked_by_task_id) as locked_by_task_id,
    coalesce(hp.lock_mode, ie.lock_mode) as lock_mode,
    -- Calculate final quantity
    coalesce(hp.cumulative_qty_from_hourly, 0) + coalesce(ie.incremental_qty, 0) as quantity,
    -- Use most recent event IDs
    coalesce(ie.latest_hu_event_id, hp.latest_hu_event_id) as latest_hu_event_id,
    coalesce(ie.latest_quant_event_id, hp.latest_quant_event_id) as latest_quant_event_id,
    -- Latest attributes from either source
    coalesce(ie.hu_event_seq, hp.hu_event_seq) as hu_event_seq,
    coalesce(ie.hu_id, hp.hu_id) as hu_id,
    coalesce(ie.hu_event_type, hp.hu_event_type) as hu_event_type,
    coalesce(ie.session_id, hp.session_id) as session_id,
    coalesce(ie.task_id, hp.task_id) as task_id,
    coalesce(ie.correlation_id, hp.correlation_id) as correlation_id,
    coalesce(ie.storage_id, hp.storage_id) as storage_id,
    coalesce(ie.outer_hu_id, hp.outer_hu_id) as outer_hu_id,
    coalesce(ie.effective_storage_id, hp.effective_storage_id) as effective_storage_id,
    coalesce(ie.sku_id, hp.sku_id) as sku_id,
    -- Handling unit attributes
    coalesce(ie.hu_kind_id, hp.hu_kind_id) as hu_kind_id,
    coalesce(ie.hu_state, hp.hu_state) as hu_state,
    coalesce(ie.hu_attrs, hp.hu_attrs) as hu_attrs,
    coalesce(ie.hu_created_at, hp.hu_created_at) as hu_created_at,
    coalesce(ie.hu_updated_at, hp.hu_updated_at) as hu_updated_at,
    coalesce(ie.hu_lock_task_id, hp.hu_lock_task_id) as hu_lock_task_id,
    coalesce(ie.hu_effective_storage_id, hp.hu_effective_storage_id) as hu_effective_storage_id,
    coalesce(ie.hu_kind_code, hp.hu_kind_code) as hu_kind_code,
    coalesce(ie.hu_kind_name, hp.hu_kind_name) as hu_kind_name,
    -- Storage bin attributes
    coalesce(ie.storage_bin_code, hp.storage_bin_code) as storage_bin_code,
    coalesce(ie.storage_bin_description, hp.storage_bin_description) as storage_bin_description,
    coalesce(ie.storage_bin_status, hp.storage_bin_status) as storage_bin_status,
    coalesce(ie.storage_aisle, hp.storage_aisle) as storage_aisle,
    coalesce(ie.storage_bay, hp.storage_bay) as storage_bay,
    coalesce(ie.storage_level, hp.storage_level) as storage_level,
    coalesce(ie.storage_position, hp.storage_position) as storage_position,
    coalesce(ie.storage_area_code, hp.storage_area_code) as storage_area_code,
    coalesce(ie.storage_area_description, hp.storage_area_description) as storage_area_description,
    coalesce(ie.storage_zone_code, hp.storage_zone_code) as storage_zone_code,
    coalesce(ie.storage_zone_description, hp.storage_zone_description) as storage_zone_description,
    -- SKU attributes
    coalesce(ie.sku_name, hp.sku_name) as sku_name,
    coalesce(ie.sku_category, hp.sku_category) as sku_category,
    coalesce(ie.sku_brand, hp.sku_brand) as sku_brand,
    coalesce(ie.sku_fulfillment_type, hp.sku_fulfillment_type) as sku_fulfillment_type,
    -- Metadata
    coalesce(ie.last_event_time, hp.last_hour_window) as last_update_time,
    (SELECT target_time FROM target_hour) as query_time
FROM hourly_position hp
FULL OUTER JOIN incremental_events ie
    ON hp.wh_id = ie.wh_id
    AND hp.hu_code = ie.hu_code
    AND hp.sku_code = ie.sku_code
    AND hp.uom = ie.uom
    AND hp.bucket = ie.bucket
    AND hp.batch = ie.batch
    AND hp.price = ie.price
    AND hp.inclusion_status = ie.inclusion_status
    AND hp.locked_by_task_id = ie.locked_by_task_id
    AND hp.lock_mode = ie.lock_mode
WHERE coalesce(hp.cumulative_qty_from_hourly, 0) + coalesce(ie.incremental_qty, 0) != 0;

-- Example queries to test the view:
-- 
-- 1. Get current inventory position for warehouse 1:
-- SELECT * FROM wms_inventory_position_at_time(wh_id=1, target_time=now())
--
-- 2. Get inventory position at a specific time:
-- SELECT * FROM wms_inventory_position_at_time(wh_id=1, target_time='2025-08-08 14:30:00')
--
-- 3. Get position for a specific SKU at a point in time:
-- SELECT * FROM wms_inventory_position_at_time(wh_id=1, target_time='2025-08-08 14:30:00') 
-- WHERE sku_code = 'SKU123'
--
-- 4. Aggregate by storage area:
-- SELECT 
--     storage_area_code,
--     count(DISTINCT sku_code) as unique_skus,
--     sum(quantity) as total_quantity
-- FROM wms_inventory_position_at_time(wh_id=1, target_time=now())
-- GROUP BY storage_area_code
-- ORDER BY total_quantity DESC;