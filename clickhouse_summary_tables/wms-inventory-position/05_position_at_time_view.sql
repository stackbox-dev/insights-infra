-- Optimized parameterized view for WMS inventory position at a specific point in time
-- Uses 3-tier architecture with weekly snapshots for guaranteed sub-second performance
-- Requires ClickHouse 23.1+ for parameterized view support
--
-- Usage examples:
-- SELECT * FROM wms_inventory_position_at_time(wh_id=1, target_time='2025-08-08 14:30:00')
-- SELECT * FROM wms_inventory_position_at_time(wh_id=1, target_time=now())
--
-- Performance note: For better performance, consider using wms_inventory_position_at_time_simple
-- which only queries hourly data and is much faster for recent dates

DROP VIEW IF EXISTS wms_inventory_position_at_time;

CREATE VIEW wms_inventory_position_at_time AS
WITH 
-- Parameters with types
params AS (
    SELECT 
        {wh_id:UInt64} as param_wh_id,
        {target_time:DateTime64(3)} as param_target_time
),
-- Find the most recent weekly snapshot before or at target time
-- This subquery uses the index on (wh_id, snapshot_timestamp) for fast lookup
latest_snapshot AS (
    SELECT *
    FROM wms_inventory_weekly_snapshot
    WHERE wh_id = (SELECT param_wh_id FROM params)
      AND snapshot_timestamp = (
          SELECT max(snapshot_timestamp)
          FROM wms_inventory_weekly_snapshot
          WHERE wh_id = (SELECT param_wh_id FROM params)
            AND snapshot_timestamp <= (SELECT param_target_time FROM params)
      )
),
-- Get the snapshot timestamp for use in next CTEs
snapshot_time AS (
    SELECT 
        COALESCE(max(snapshot_timestamp), toDateTime('1970-01-01')) as snapshot_ts
    FROM latest_snapshot
),
-- Sum hourly changes from snapshot to target hour (excluding current hour)
hourly_changes AS (
    SELECT 
        hp.wh_id as wh_id,
        hp.hu_code as hu_code,
        hp.sku_code as sku_code,
        hp.uom as uom,
        hp.bucket as bucket,
        hp.batch as batch,
        hp.price as price,
        hp.inclusion_status as inclusion_status,
        hp.locked_by_task_id as locked_by_task_id,
        hp.lock_mode as lock_mode,
        sum(hp.hourly_qty_change) as qty_since_snapshot,
        sum(hp.event_count) as events_since_snapshot,
        argMax(hp.latest_hu_event_id, hp.hour_window) as latest_hu_event_id,
        argMax(hp.latest_quant_event_id, hp.hour_window) as latest_quant_event_id,
        -- Latest values for all fields
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
        argMax(hp.sku_fulfillment_type, hp.hour_window) as sku_fulfillment_type,
        max(hp.last_event_time) as last_update_time
    FROM wms_inventory_hourly_position hp
    CROSS JOIN params p
    CROSS JOIN snapshot_time st
    WHERE hp.wh_id = p.param_wh_id
      AND hp.hour_window > st.snapshot_ts
      AND hp.hour_window < toStartOfHour(p.param_target_time)
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
-- Get events for the current hour using FINAL for automatic deduplication
current_hour_events AS (
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
        count() as current_hour_events,
        argMax(hu_event_id, hu_event_timestamp) as latest_hu_event_id,
        argMax(quant_event_id, hu_event_timestamp) as latest_quant_event_id,
        argMax(hu_event_seq, hu_event_timestamp) as hu_event_seq,
        argMax(hu_id, hu_event_timestamp) as hu_id,
        argMax(hu_event_type, hu_event_timestamp) as hu_event_type,
        argMax(hu_event_payload, hu_event_timestamp) as hu_event_payload,
        argMax(hu_event_attrs, hu_event_timestamp) as hu_event_attrs,
        argMax(session_id, hu_event_timestamp) as session_id,
        argMax(task_id, hu_event_timestamp) as task_id,
        argMax(correlation_id, hu_event_timestamp) as correlation_id,
        argMax(storage_id, hu_event_timestamp) as storage_id,
        argMax(outer_hu_id, hu_event_timestamp) as outer_hu_id,
        argMax(effective_storage_id, hu_event_timestamp) as effective_storage_id,
        argMax(sku_id, hu_event_timestamp) as sku_id,
        argMax(hu_kind_id, hu_event_timestamp) as hu_kind_id,
        argMax(hu_state, hu_event_timestamp) as hu_state,
        argMax(hu_attrs, hu_event_timestamp) as hu_attrs,
        argMax(hu_created_at, hu_event_timestamp) as hu_created_at,
        argMax(hu_updated_at, hu_event_timestamp) as hu_updated_at,
        argMax(hu_lock_task_id, hu_event_timestamp) as hu_lock_task_id,
        argMax(hu_effective_storage_id, hu_event_timestamp) as hu_effective_storage_id,
        argMax(hu_kind_code, hu_event_timestamp) as hu_kind_code,
        argMax(hu_kind_name, hu_event_timestamp) as hu_kind_name,
        argMax(storage_bin_code, hu_event_timestamp) as storage_bin_code,
        argMax(storage_bin_description, hu_event_timestamp) as storage_bin_description,
        argMax(storage_bin_status, hu_event_timestamp) as storage_bin_status,
        argMax(storage_aisle, hu_event_timestamp) as storage_aisle,
        argMax(storage_bay, hu_event_timestamp) as storage_bay,
        argMax(storage_level, hu_event_timestamp) as storage_level,
        argMax(storage_position, hu_event_timestamp) as storage_position,
        argMax(storage_area_code, hu_event_timestamp) as storage_area_code,
        argMax(storage_area_description, hu_event_timestamp) as storage_area_description,
        argMax(storage_zone_code, hu_event_timestamp) as storage_zone_code,
        argMax(storage_zone_description, hu_event_timestamp) as storage_zone_description,
        argMax(sku_name, hu_event_timestamp) as sku_name,
        argMax(sku_category, hu_event_timestamp) as sku_category,
        argMax(sku_brand, hu_event_timestamp) as sku_brand,
        argMax(sku_fulfillment_type, hu_event_timestamp) as sku_fulfillment_type,
        max(hu_event_timestamp) as last_update_time
    FROM wms_inventory_events_enriched FINAL
    CROSS JOIN params p
    WHERE wh_id = p.param_wh_id
      AND hu_event_timestamp >= toStartOfHour(p.param_target_time)
      AND hu_event_timestamp <= p.param_target_time
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
)
-- Combine all three sources: weekly snapshot + hourly changes + current hour events
SELECT 
    COALESCE(s.wh_id, h.wh_id, e.wh_id) as wh_id,
    COALESCE(s.hu_code, h.hu_code, e.hu_code) as hu_code,
    COALESCE(s.sku_code, h.sku_code, e.sku_code) as sku_code,
    COALESCE(s.uom, h.uom, e.uom) as uom,
    COALESCE(s.bucket, h.bucket, e.bucket) as bucket,
    COALESCE(s.batch, h.batch, e.batch) as batch,
    COALESCE(s.price, h.price, e.price) as price,
    COALESCE(s.inclusion_status, h.inclusion_status, e.inclusion_status) as inclusion_status,
    COALESCE(s.locked_by_task_id, h.locked_by_task_id, e.locked_by_task_id) as locked_by_task_id,
    COALESCE(s.lock_mode, h.lock_mode, e.lock_mode) as lock_mode,
    -- Calculate final quantity: snapshot + hourly changes + current hour
    COALESCE(s.cumulative_qty, 0) + 
    COALESCE(h.qty_since_snapshot, 0) + 
    COALESCE(e.current_hour_qty, 0) as quantity,
    -- Total events processed
    COALESCE(s.total_event_count, 0) + 
    COALESCE(h.events_since_snapshot, 0) + 
    COALESCE(e.current_hour_events, 0) as total_events,
    -- Use most recent event IDs
    COALESCE(e.latest_hu_event_id, h.latest_hu_event_id, s.latest_hu_event_id) as latest_hu_event_id,
    COALESCE(e.latest_quant_event_id, h.latest_quant_event_id, s.latest_quant_event_id) as latest_quant_event_id,
    -- Latest attributes from most recent source
    COALESCE(e.hu_event_seq, h.hu_event_seq, s.hu_event_seq) as hu_event_seq,
    COALESCE(e.hu_id, h.hu_id, s.hu_id) as hu_id,
    COALESCE(e.hu_event_type, h.hu_event_type, s.hu_event_type) as hu_event_type,
    COALESCE(e.session_id, h.session_id, s.session_id) as session_id,
    COALESCE(e.task_id, h.task_id, s.task_id) as task_id,
    COALESCE(e.correlation_id, h.correlation_id, s.correlation_id) as correlation_id,
    COALESCE(e.storage_id, h.storage_id, s.storage_id) as storage_id,
    COALESCE(e.outer_hu_id, h.outer_hu_id, s.outer_hu_id) as outer_hu_id,
    COALESCE(e.effective_storage_id, h.effective_storage_id, s.effective_storage_id) as effective_storage_id,
    COALESCE(e.sku_id, h.sku_id, s.sku_id) as sku_id,
    -- Handling unit attributes
    COALESCE(e.hu_kind_id, h.hu_kind_id, s.hu_kind_id) as hu_kind_id,
    COALESCE(e.hu_state, h.hu_state, s.hu_state) as hu_state,
    COALESCE(e.hu_attrs, h.hu_attrs, s.hu_attrs) as hu_attrs,
    COALESCE(e.hu_created_at, h.hu_created_at, s.hu_created_at) as hu_created_at,
    COALESCE(e.hu_updated_at, h.hu_updated_at, s.hu_updated_at) as hu_updated_at,
    COALESCE(e.hu_lock_task_id, h.hu_lock_task_id, s.hu_lock_task_id) as hu_lock_task_id,
    COALESCE(e.hu_effective_storage_id, h.hu_effective_storage_id, s.hu_effective_storage_id) as hu_effective_storage_id,
    COALESCE(e.hu_kind_code, h.hu_kind_code, s.hu_kind_code) as hu_kind_code,
    COALESCE(e.hu_kind_name, h.hu_kind_name, s.hu_kind_name) as hu_kind_name,
    -- Storage bin attributes (take from most recent source, but handle new SKUs)
    CASE 
        WHEN e.wh_id IS NOT NULL THEN e.storage_bin_code
        WHEN h.wh_id IS NOT NULL THEN h.storage_bin_code
        ELSE s.storage_bin_code
    END as storage_bin_code,
    CASE 
        WHEN e.wh_id IS NOT NULL THEN e.storage_bin_description
        WHEN h.wh_id IS NOT NULL THEN h.storage_bin_description
        ELSE s.storage_bin_description
    END as storage_bin_description,
    CASE 
        WHEN e.wh_id IS NOT NULL THEN e.storage_bin_status
        WHEN h.wh_id IS NOT NULL THEN h.storage_bin_status
        ELSE s.storage_bin_status
    END as storage_bin_status,
    CASE 
        WHEN e.wh_id IS NOT NULL THEN e.storage_aisle
        WHEN h.wh_id IS NOT NULL THEN h.storage_aisle
        ELSE s.storage_aisle
    END as storage_aisle,
    CASE 
        WHEN e.wh_id IS NOT NULL THEN e.storage_bay
        WHEN h.wh_id IS NOT NULL THEN h.storage_bay
        ELSE s.storage_bay
    END as storage_bay,
    CASE 
        WHEN e.wh_id IS NOT NULL THEN e.storage_level
        WHEN h.wh_id IS NOT NULL THEN h.storage_level
        ELSE s.storage_level
    END as storage_level,
    CASE 
        WHEN e.wh_id IS NOT NULL THEN e.storage_position
        WHEN h.wh_id IS NOT NULL THEN h.storage_position
        ELSE s.storage_position
    END as storage_position,
    CASE 
        WHEN e.wh_id IS NOT NULL THEN e.storage_area_code
        WHEN h.wh_id IS NOT NULL THEN h.storage_area_code
        ELSE s.storage_area_code
    END as storage_area_code,
    CASE 
        WHEN e.wh_id IS NOT NULL THEN e.storage_area_description
        WHEN h.wh_id IS NOT NULL THEN h.storage_area_description
        ELSE s.storage_area_description
    END as storage_area_description,
    CASE 
        WHEN e.wh_id IS NOT NULL THEN e.storage_zone_code
        WHEN h.wh_id IS NOT NULL THEN h.storage_zone_code
        ELSE s.storage_zone_code
    END as storage_zone_code,
    CASE 
        WHEN e.wh_id IS NOT NULL THEN e.storage_zone_description
        WHEN h.wh_id IS NOT NULL THEN h.storage_zone_description
        ELSE s.storage_zone_description
    END as storage_zone_description,
    -- SKU attributes (take from most recent source with data)
    CASE 
        WHEN e.wh_id IS NOT NULL THEN e.sku_name
        WHEN h.wh_id IS NOT NULL THEN h.sku_name
        ELSE s.sku_name
    END as sku_name,
    CASE 
        WHEN e.wh_id IS NOT NULL THEN e.sku_category
        WHEN h.wh_id IS NOT NULL THEN h.sku_category
        ELSE s.sku_category
    END as sku_category,
    CASE 
        WHEN e.wh_id IS NOT NULL THEN e.sku_brand
        WHEN h.wh_id IS NOT NULL THEN h.sku_brand
        ELSE s.sku_brand
    END as sku_brand,
    CASE 
        WHEN e.wh_id IS NOT NULL THEN e.sku_fulfillment_type
        WHEN h.wh_id IS NOT NULL THEN h.sku_fulfillment_type
        ELSE s.sku_fulfillment_type
    END as sku_fulfillment_type,
    -- Metadata
    COALESCE(e.last_update_time, h.last_update_time, s.last_event_time) as last_update_time,
    (SELECT param_target_time FROM params) as query_time,
    (SELECT snapshot_ts FROM snapshot_time) as base_snapshot_time
FROM latest_snapshot s
FULL OUTER JOIN hourly_changes h
    ON s.wh_id = h.wh_id
    AND s.hu_code = h.hu_code
    AND s.sku_code = h.sku_code
    AND s.uom = h.uom
    AND s.bucket = h.bucket
    AND s.batch = h.batch
    AND s.price = h.price
    AND s.inclusion_status = h.inclusion_status
    AND s.locked_by_task_id = h.locked_by_task_id
    AND s.lock_mode = h.lock_mode
FULL OUTER JOIN current_hour_events e
    ON COALESCE(s.wh_id, h.wh_id) = e.wh_id
    AND COALESCE(s.hu_code, h.hu_code) = e.hu_code
    AND COALESCE(s.sku_code, h.sku_code) = e.sku_code
    AND COALESCE(s.uom, h.uom) = e.uom
    AND COALESCE(s.bucket, h.bucket) = e.bucket
    AND COALESCE(s.batch, h.batch) = e.batch
    AND COALESCE(s.price, h.price) = e.price
    AND COALESCE(s.inclusion_status, h.inclusion_status) = e.inclusion_status
    AND COALESCE(s.locked_by_task_id, h.locked_by_task_id) = e.locked_by_task_id
    AND COALESCE(s.lock_mode, h.lock_mode) = e.lock_mode
WHERE COALESCE(s.cumulative_qty, 0) + COALESCE(h.qty_since_snapshot, 0) + COALESCE(e.current_hour_qty, 0) != 0
  AND COALESCE(s.wh_id, h.wh_id, e.wh_id) = (SELECT param_wh_id FROM params);