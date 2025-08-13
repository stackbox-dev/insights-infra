-- ClickHouse Materialized View for WMS Inventory Hourly Position Aggregation
-- Automatically processes new events from wms_inventory_enriched_raw_events_mv
-- Aggregates inventory movements hourly for efficient time-series analysis

CREATE MATERIALIZED VIEW IF NOT EXISTS wms_inventory_hourly_position_mv
TO wms_inventory_hourly_position
AS
SELECT
    toStartOfHour(hu_event_timestamp) as hour_window,
    wh_id,
    hu_id,
    hu_code,
    sku_id,
    
    -- SKU enrichment fields for aggregation
    sku_code,
    sku_name,
    sku_category,
    sku_brand,
    sku_sub_brand,
    
    -- Inventory attributes
    uom,
    bucket,
    batch,
    price,
    inclusion_status,
    locked_by_task_id,
    lock_mode,
    
    -- Storage location from enrichment
    storage_bin_code,
    storage_zone_code,
    storage_area_code,
    storage_aisle,
    storage_bay,
    storage_level,
    
    -- Aggregated metrics
    sum(qty_added) as hourly_qty_change,
    count() as event_count,
    
    -- Latest event tracking
    argMax(hu_event_id, hu_event_timestamp) as latest_hu_event_id,
    argMax(quant_event_id, hu_event_timestamp) as latest_quant_event_id,
    min(hu_event_timestamp) as first_event_time,
    max(hu_event_timestamp) as last_event_time,
    
    -- Latest state information
    anyLast(hu_event_type) as latest_event_type,
    anyLast(hu_state) as latest_hu_state,
    anyLast(session_id) as latest_session_id,
    anyLast(task_id) as latest_task_id,
    anyLast(correlation_id) as latest_correlation_id,
    anyLast(effective_storage_id) as latest_effective_storage_id,
    
    -- Latest handling unit attributes
    anyLast(hu_kind_id) as hu_kind_id,
    anyLast(hu_attrs) as hu_attrs,
    anyLast(hu_lock_task_id) as hu_lock_task_id,
    anyLast(hu_effective_storage_id) as hu_effective_storage_id,
    
    -- Latest storage attributes  
    anyLast(storage_bin_description) as storage_bin_description,
    anyLast(storage_multi_sku) as storage_multi_sku,
    anyLast(storage_multi_batch) as storage_multi_batch,
    anyLast(storage_picking_position) as storage_picking_position,
    anyLast(storage_putaway_position) as storage_putaway_position,
    
    -- Latest SKU attributes
    anyLast(sku_principal_id) as sku_principal_id,
    anyLast(sku_node_id) as sku_node_id,
    anyLast(sku_product) as sku_product,
    anyLast(sku_category_group) as sku_category_group,
    anyLast(sku_fulfillment_type) as sku_fulfillment_type,
    anyLast(sku_inventory_type) as sku_inventory_type,
    anyLast(sku_l0_weight) as sku_l0_weight,
    anyLast(sku_l0_volume) as sku_l0_volume,
    anyLast(sku_active) as sku_active
FROM wms_inventory_enriched_raw_events_mv
GROUP BY
    toStartOfHour(hu_event_timestamp),
    wh_id,
    hu_id,
    hu_code,
    sku_id,
    sku_code,
    sku_name,
    sku_category,
    sku_brand,
    sku_sub_brand,
    uom,
    bucket,
    batch,
    price,
    inclusion_status,
    locked_by_task_id,
    lock_mode,
    storage_bin_code,
    storage_zone_code,
    storage_area_code,
    storage_aisle,
    storage_bay,
    storage_level
HAVING sum(qty_added) != 0;