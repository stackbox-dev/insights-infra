-- ClickHouse Materialized View for WMS Inventory Enriched Raw Events
-- Enriches inventory_staging with dimension data
-- Enriches with handling_units, storage_bin, storage_bin_master, SKU data

CREATE MATERIALIZED VIEW IF NOT EXISTS wms_inventory_enriched_raw_events_mv
ENGINE = ReplacingMergeTree(hu_event_timestamp)
PARTITION BY toYYYYMM(hu_event_timestamp)  
ORDER BY (wh_id, hu_event_timestamp, hu_event_id, quant_event_id)
AS
SELECT
    -- Core fields from basic events
    ie.hu_event_id,
    ie.wh_id,
    ie.hu_event_seq,
    ie.hu_id,
    ie.hu_event_type,
    ie.hu_event_timestamp,
    ie.hu_event_payload,
    ie.hu_event_attrs,
    ie.session_id,
    ie.task_id,
    ie.correlation_id,
    ie.storage_id,
    ie.outer_hu_id,
    ie.effective_storage_id,
    ie.quant_event_id,
    ie.sku_id,
    ie.uom,
    ie.bucket,
    ie.batch,
    ie.price,
    ie.inclusion_status,
    ie.locked_by_task_id,
    ie.lock_mode,
    ie.qty_added,
    
    -- Handling Unit enrichment (based on hu_id)
    hu.code AS hu_code,
    hu.kindId AS hu_kind_id,
    hu.sessionId AS hu_session_id,
    hu.taskId AS hu_task_id,
    hu.storageId AS hu_storage_id,
    hu.outerHuId AS hu_outer_hu_id,
    hu.state AS hu_state,
    hu.attrs AS hu_attrs,
    hu.lockTaskId AS hu_lock_task_id,
    hu.effectiveStorageId AS hu_effective_storage_id,
    hu.createdAt AS hu_created_at,
    hu.updatedAt AS hu_updated_at,
    
    -- Storage Bin enrichment (based on storage_id or effective_storage_id)
    sb.code AS storage_bin_code,
    sb.createdAt AS storage_bin_created_at,
    sb.updatedAt AS storage_bin_updated_at,
    
    -- Storage Bin Master enrichment (based on bin_code)
    sbm.bin_description AS storage_bin_description,
    sbm.bin_status AS storage_bin_status,
    sbm.bin_hu_id AS storage_bin_hu_id,
    sbm.multi_sku AS storage_multi_sku,
    sbm.multi_batch AS storage_multi_batch,
    sbm.picking_position AS storage_picking_position,
    sbm.putaway_position AS storage_putaway_position,
    sbm.rank AS storage_bin_rank,
    sbm.aisle AS storage_aisle,
    sbm.bay AS storage_bay,
    sbm.level AS storage_level,
    sbm.position AS storage_position,
    sbm.depth AS storage_depth,
    sbm.bin_type_code AS storage_bin_type_code,
    sbm.zone_id AS storage_zone_id,
    sbm.zone_code AS storage_zone_code,
    sbm.zone_description AS storage_zone_description,
    sbm.area_id AS storage_area_id,
    sbm.area_code AS storage_area_code,
    sbm.area_description AS storage_area_description,
    sbm.x1 AS storage_x1,
    sbm.y1 AS storage_y1,
    sbm.max_volume_in_cc AS storage_max_volume_in_cc,
    sbm.max_weight_in_kg AS storage_max_weight_in_kg,
    sbm.pallet_capacity AS storage_pallet_capacity,
    
    -- SKU enrichment from combined parameterized view
    sku.principal_id AS sku_principal_id,
    sku.node_id AS sku_node_id,
    sku.category AS sku_category,
    sku.product AS sku_product,
    sku.product_id AS sku_product_id,
    sku.category_group AS sku_category_group,
    sku.sub_brand AS sku_sub_brand,
    sku.brand AS sku_brand,
    sku.code AS sku_code,
    sku.name AS sku_name,
    sku.short_description AS sku_short_description,
    sku.description AS sku_description,
    sku.fulfillment_type AS sku_fulfillment_type,
    sku.inventory_type AS sku_inventory_type,
    sku.shelf_life AS sku_shelf_life,
    sku.handling_unit_type AS sku_handling_unit_type,
    sku.l0_units AS sku_l0_units,
    sku.l1_units AS sku_l1_units,
    sku.l2_units AS sku_l2_units,
    sku.l3_units AS sku_l3_units,
    sku.l0_weight AS sku_l0_weight,
    sku.l0_volume AS sku_l0_volume,
    sku.active AS sku_active
FROM wms_inventory_staging ie
-- Handling Unit enrichment
LEFT JOIN wms_handling_units hu ON ie.hu_id = hu.id
-- Storage Bin enrichment (prefer effective_storage_id over storage_id)
LEFT JOIN wms_storage_bins sb ON ie.effective_storage_id = sb.id
-- Storage Bin Master enrichment
LEFT JOIN wms_storage_bin_master sbm ON sb.id = sbm.bin_id
-- SKU enrichment using combined parameterized view
LEFT JOIN encarta_skus_combined(node_id = ie.wh_id) sku ON ie.sku_id = sku.sku_id;