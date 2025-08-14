-- ClickHouse Materialized View for WMS Inventory Enriched
-- Enriches inventory_staging with dimension data
-- Enriches with handling_units, storage_bin, storage_bin_master, SKU data

CREATE MATERIALIZED VIEW IF NOT EXISTS wms_inventory_enriched_mv
TO wms_inventory_events_enriched
AS
SELECT
    -- Core fields from staging events (using original field names from Flink)
    ie.event_id AS hu_event_id,
    ie.wh_id,
    ie.seq AS hu_event_seq,
    ie.hu_id,
    ie.event_type AS hu_event_type,
    ie.`timestamp` AS hu_event_timestamp,
    ie.payload AS hu_event_payload,
    ie.attrs AS hu_event_attrs,
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
    ie.quant_iloc AS quant_iloc,  -- Added field from Flink
    
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
    sbm.bin_code AS storage_bin_code,
    sbm.createdAt AS storage_bin_created_at,
    sbm.updatedAt AS storage_bin_updated_at,
    
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
    
    -- SKU enrichment with overrides logic (COALESCE: override > master > default)
    COALESCE(so.code, sm.code, '') AS sku_code,
    COALESCE(so.name, sm.name, '') AS sku_name,
    COALESCE(so.short_description, sm.short_description, '') AS sku_short_description,
    COALESCE(so.description, sm.description, '') AS sku_description,
    -- Product hierarchy always from master (never overridden)
    sm.category AS sku_category,
    sm.category_group AS sku_category_group,
    sm.product AS sku_product,
    sm.product_id AS sku_product_id,
    sm.brand AS sku_brand,
    sm.sub_brand AS sku_sub_brand,
    COALESCE(so.fulfillment_type, sm.fulfillment_type, '') AS sku_fulfillment_type,
    COALESCE(so.inventory_type, sm.inventory_type, '') AS sku_inventory_type,
    COALESCE(so.shelf_life, sm.shelf_life, 0) AS sku_shelf_life,
    COALESCE(so.handling_unit_type, sm.handling_unit_type, '') AS sku_handling_unit_type,
    sm.active AS sku_active,
    sm.principal_id AS sku_principal_id,
    COALESCE(so.node_id, 0) AS sku_node_id,
    
    -- SKU identifiers and tags
    COALESCE(so.identifier1, sm.identifier1, '') AS sku_identifier1,
    COALESCE(so.identifier2, sm.identifier2, '') AS sku_identifier2,
    COALESCE(so.tag1, sm.tag1, '') AS sku_tag1,
    COALESCE(so.tag2, sm.tag2, '') AS sku_tag2,
    COALESCE(so.tag3, sm.tag3, '') AS sku_tag3,
    COALESCE(so.tag4, sm.tag4, '') AS sku_tag4,
    COALESCE(so.tag5, sm.tag5, '') AS sku_tag5,
    COALESCE(so.tag6, sm.tag6, '') AS sku_tag6,
    COALESCE(so.tag7, sm.tag7, '') AS sku_tag7,
    COALESCE(so.tag8, sm.tag8, '') AS sku_tag8,
    COALESCE(so.tag9, sm.tag9, '') AS sku_tag9,
    COALESCE(so.tag10, sm.tag10, '') AS sku_tag10,
    
    -- SKU UOM hierarchy L0
    COALESCE(so.l0_name, sm.l0_name, '') AS sku_l0_name,
    COALESCE(so.l0_units, sm.l0_units, 0) AS sku_l0_units,
    COALESCE(so.l0_weight, sm.l0_weight, 0) AS sku_l0_weight,
    COALESCE(so.l0_volume, sm.l0_volume, 0) AS sku_l0_volume,
    COALESCE(so.l0_package_type, sm.l0_package_type, '') AS sku_l0_package_type,
    COALESCE(so.l0_length, sm.l0_length, 0) AS sku_l0_length,
    COALESCE(so.l0_width, sm.l0_width, 0) AS sku_l0_width,
    COALESCE(so.l0_height, sm.l0_height, 0) AS sku_l0_height,
    COALESCE(so.l0_itf_code, sm.l0_itf_code, '') AS sku_l0_itf_code,
    
    -- SKU UOM hierarchy L1
    COALESCE(so.l1_name, sm.l1_name, '') AS sku_l1_name,
    COALESCE(so.l1_units, sm.l1_units, 0) AS sku_l1_units,
    COALESCE(so.l1_weight, sm.l1_weight, 0) AS sku_l1_weight,
    COALESCE(so.l1_volume, sm.l1_volume, 0) AS sku_l1_volume,
    COALESCE(so.l1_package_type, sm.l1_package_type, '') AS sku_l1_package_type,
    COALESCE(so.l1_length, sm.l1_length, 0) AS sku_l1_length,
    COALESCE(so.l1_width, sm.l1_width, 0) AS sku_l1_width,
    COALESCE(so.l1_height, sm.l1_height, 0) AS sku_l1_height,
    COALESCE(so.l1_itf_code, sm.l1_itf_code, '') AS sku_l1_itf_code,
    
    -- SKU UOM hierarchy L2
    COALESCE(so.l2_name, sm.l2_name, '') AS sku_l2_name,
    COALESCE(so.l2_units, sm.l2_units, 0) AS sku_l2_units,
    COALESCE(so.l2_weight, sm.l2_weight, 0) AS sku_l2_weight,
    COALESCE(so.l2_volume, sm.l2_volume, 0) AS sku_l2_volume,
    COALESCE(so.l2_package_type, sm.l2_package_type, '') AS sku_l2_package_type,
    COALESCE(so.l2_length, sm.l2_length, 0) AS sku_l2_length,
    COALESCE(so.l2_width, sm.l2_width, 0) AS sku_l2_width,
    COALESCE(so.l2_height, sm.l2_height, 0) AS sku_l2_height,
    COALESCE(so.l2_itf_code, sm.l2_itf_code, '') AS sku_l2_itf_code,
    
    -- SKU UOM hierarchy L3
    COALESCE(so.l3_name, sm.l3_name, '') AS sku_l3_name,
    COALESCE(so.l3_units, sm.l3_units, 0) AS sku_l3_units,
    COALESCE(so.l3_weight, sm.l3_weight, 0) AS sku_l3_weight,
    COALESCE(so.l3_volume, sm.l3_volume, 0) AS sku_l3_volume,
    COALESCE(so.l3_package_type, sm.l3_package_type, '') AS sku_l3_package_type,
    COALESCE(so.l3_length, sm.l3_length, 0) AS sku_l3_length,
    COALESCE(so.l3_width, sm.l3_width, 0) AS sku_l3_width,
    COALESCE(so.l3_height, sm.l3_height, 0) AS sku_l3_height,
    COALESCE(so.l3_itf_code, sm.l3_itf_code, '') AS sku_l3_itf_code,
    
    -- SKU packaging config
    COALESCE(so.cases_per_layer, sm.cases_per_layer, 0) AS sku_cases_per_layer,
    COALESCE(so.layers, sm.layers, 0) AS sku_layers,
    COALESCE(so.avg_l0_per_put, sm.avg_l0_per_put, 0) AS sku_avg_l0_per_put,
    
    -- SKU classifications
    sm.combined_classification AS sku_combined_classification,
    
    -- SKU timestamps
    sm.created_at AS sku_created_at,
    sm.updated_at AS sku_updated_at
FROM wms_inventory_events_staging ie
-- Handling Unit enrichment
LEFT JOIN wms_handling_units hu ON ie.hu_id = hu.id
-- Storage Bin Master enrichment (using effective_storage_id as bin_id)
LEFT JOIN wms_storage_bin_master sbm ON ie.effective_storage_id = sbm.bin_id
-- SKU Master data
LEFT JOIN encarta_skus_master sm ON ie.sku_id = sm.id
-- SKU Overrides for specific warehouse (wh_id as node_id)
LEFT JOIN encarta_skus_overrides so ON ie.sku_id = so.sku_id AND ie.wh_id = so.node_id;