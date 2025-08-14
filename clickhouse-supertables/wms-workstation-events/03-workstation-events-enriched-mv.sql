-- ClickHouse Materialized View for WMS Workstation Events Enrichment
-- Populates wms_workstation_events_enriched table with enriched data
-- Enriches with handling_units, storage_bin_master, and SKUs (master + overrides)

CREATE MATERIALIZED VIEW IF NOT EXISTS wms_workstation_events_enriched_mv
TO wms_workstation_events_enriched
AS
SELECT
    -- Core fields from staging (must have explicit aliases for MV)
    we.event_type AS event_type,
    we.event_source_id AS event_source_id,
    we.event_timestamp AS event_timestamp,
    we.created_at AS created_at,
    we.wh_id AS wh_id,
    we.sku_id AS sku_id,
    we.hu_id AS hu_id,
    we.hu_code AS hu_code,
    we.batch_id AS batch_id,
    we.user_id AS user_id,
    we.task_id AS task_id,
    we.session_id AS session_id,
    we.bin_id AS bin_id,
    we.primary_quantity AS primary_quantity,
    we.secondary_quantity AS secondary_quantity,
    we.tertiary_quantity AS tertiary_quantity,
    we.price AS price,
    we.status_or_bucket AS status_or_bucket,
    we.reason AS reason,
    we.sub_reason AS sub_reason,
    we.deactivated_at AS deactivated_at,
    
    -- Handling Unit enrichment (based on hu_id)
    hu.code AS hu_enriched_code,
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
    
    -- Storage Bin Master enrichment (based on bin_id)
    sbm.bin_code AS bin_code,
    sbm.bin_created_at AS bin_created_at,
    sbm.bin_updated_at AS bin_updated_at,
    sbm.bin_description AS bin_description,
    sbm.bin_status AS bin_status,
    sbm.bin_hu_id AS bin_hu_id,
    sbm.multi_sku AS multi_sku,
    sbm.multi_batch AS multi_batch,
    sbm.picking_position AS picking_position,
    sbm.putaway_position AS putaway_position,
    sbm.rank AS bin_rank,
    sbm.aisle AS aisle,
    sbm.bay AS bay,
    sbm.level AS level,
    sbm.position AS bin_position,
    sbm.depth AS depth,
    sbm.bin_type_code AS bin_type_code,
    sbm.zone_id AS zone_id,
    sbm.zone_code AS zone_code,
    sbm.zone_description AS zone_description,
    sbm.area_id AS area_id,
    sbm.area_code AS area_code,
    sbm.area_description AS area_description,
    sbm.x1 AS x1,
    sbm.y1 AS y1,
    sbm.max_volume_in_cc AS max_volume_in_cc,
    sbm.max_weight_in_kg AS max_weight_in_kg,
    sbm.pallet_capacity AS pallet_capacity,
    
    -- SKU enrichment with overrides logic (override > master)
    sm.code AS sku_code,
    if(so.name != '', so.name, sm.name) AS sku_name,
    if(so.short_description != '', so.short_description, sm.short_description) AS sku_short_description,
    if(so.description != '', so.description, sm.description) AS sku_description,
    -- Product hierarchy always from master (never overridden)
    sm.category AS sku_category,
    sm.category_group AS sku_category_group,
    sm.product AS sku_product,
    sm.product_id AS sku_product_id,
    sm.brand AS sku_brand,
    sm.sub_brand AS sku_sub_brand,
    if(so.fulfillment_type != '', so.fulfillment_type, sm.fulfillment_type) AS sku_fulfillment_type,
    if(so.inventory_type != '', so.inventory_type, sm.inventory_type) AS sku_inventory_type,
    if(so.shelf_life != 0, so.shelf_life, sm.shelf_life) AS sku_shelf_life,
    if(so.handling_unit_type != '', so.handling_unit_type, sm.handling_unit_type) AS sku_handling_unit_type,
    sm.active AS sku_active,
    
    -- SKU identifiers and tags
    if(so.identifier1 != '', so.identifier1, sm.identifier1) AS sku_identifier1,
    if(so.identifier2 != '', so.identifier2, sm.identifier2) AS sku_identifier2,
    if(so.tag1 != '', so.tag1, sm.tag1) AS sku_tag1,
    if(so.tag2 != '', so.tag2, sm.tag2) AS sku_tag2,
    if(so.tag3 != '', so.tag3, sm.tag3) AS sku_tag3,
    if(so.tag4 != '', so.tag4, sm.tag4) AS sku_tag4,
    if(so.tag5 != '', so.tag5, sm.tag5) AS sku_tag5,
    
    -- SKU UOM hierarchy L0
    if(so.l0_name != '', so.l0_name, sm.l0_name) AS sku_l0_name,
    if(so.l0_units != 0, so.l0_units, sm.l0_units) AS sku_l0_units,
    if(so.l0_weight != 0, so.l0_weight, sm.l0_weight) AS sku_l0_weight,
    if(so.l0_volume != 0, so.l0_volume, sm.l0_volume) AS sku_l0_volume,
    if(so.l0_package_type != '', so.l0_package_type, sm.l0_package_type) AS sku_l0_package_type,
    if(so.l0_length != 0, so.l0_length, sm.l0_length) AS sku_l0_length,
    if(so.l0_width != 0, so.l0_width, sm.l0_width) AS sku_l0_width,
    if(so.l0_height != 0, so.l0_height, sm.l0_height) AS sku_l0_height,
    if(so.l0_itf_code != '', so.l0_itf_code, sm.l0_itf_code) AS sku_l0_itf_code,
    
    -- SKU UOM hierarchy L1
    if(so.l1_name != '', so.l1_name, sm.l1_name) AS sku_l1_name,
    if(so.l1_units != 0, so.l1_units, sm.l1_units) AS sku_l1_units,
    if(so.l1_weight != 0, so.l1_weight, sm.l1_weight) AS sku_l1_weight,
    if(so.l1_volume != 0, so.l1_volume, sm.l1_volume) AS sku_l1_volume,
    if(so.l1_package_type != '', so.l1_package_type, sm.l1_package_type) AS sku_l1_package_type,
    if(so.l1_length != 0, so.l1_length, sm.l1_length) AS sku_l1_length,
    if(so.l1_width != 0, so.l1_width, sm.l1_width) AS sku_l1_width,
    if(so.l1_height != 0, so.l1_height, sm.l1_height) AS sku_l1_height,
    if(so.l1_itf_code != '', so.l1_itf_code, sm.l1_itf_code) AS sku_l1_itf_code,
    
    -- SKU UOM hierarchy L2
    if(so.l2_name != '', so.l2_name, sm.l2_name) AS sku_l2_name,
    if(so.l2_units != 0, so.l2_units, sm.l2_units) AS sku_l2_units,
    if(so.l2_weight != 0, so.l2_weight, sm.l2_weight) AS sku_l2_weight,
    if(so.l2_volume != 0, so.l2_volume, sm.l2_volume) AS sku_l2_volume,
    if(so.l2_package_type != '', so.l2_package_type, sm.l2_package_type) AS sku_l2_package_type,
    if(so.l2_length != 0, so.l2_length, sm.l2_length) AS sku_l2_length,
    if(so.l2_width != 0, so.l2_width, sm.l2_width) AS sku_l2_width,
    if(so.l2_height != 0, so.l2_height, sm.l2_height) AS sku_l2_height,
    if(so.l2_itf_code != '', so.l2_itf_code, sm.l2_itf_code) AS sku_l2_itf_code,
    
    -- SKU UOM hierarchy L3
    if(so.l3_name != '', so.l3_name, sm.l3_name) AS sku_l3_name,
    if(so.l3_units != 0, so.l3_units, sm.l3_units) AS sku_l3_units,
    if(so.l3_weight != 0, so.l3_weight, sm.l3_weight) AS sku_l3_weight,
    if(so.l3_volume != 0, so.l3_volume, sm.l3_volume) AS sku_l3_volume,
    if(so.l3_package_type != '', so.l3_package_type, sm.l3_package_type) AS sku_l3_package_type,
    if(so.l3_length != 0, so.l3_length, sm.l3_length) AS sku_l3_length,
    if(so.l3_width != 0, so.l3_width, sm.l3_width) AS sku_l3_width,
    if(so.l3_height != 0, so.l3_height, sm.l3_height) AS sku_l3_height,
    if(so.l3_itf_code != '', so.l3_itf_code, sm.l3_itf_code) AS sku_l3_itf_code,
    
    -- SKU packaging config
    if(so.cases_per_layer != 0, so.cases_per_layer, sm.cases_per_layer) AS sku_cases_per_layer,
    if(so.layers != 0, so.layers, sm.layers) AS sku_layers,
    if(so.avg_l0_per_put != 0, so.avg_l0_per_put, sm.avg_l0_per_put) AS sku_avg_l0_per_put,
    
    -- SKU classifications (JSON merge: override properties overwrite master)
    JSONExtractRaw(JSONMergePatch(
        if(sm.combined_classification = '', '{}', sm.combined_classification),
        if(so.combined_classification = '', '{}', so.combined_classification)
    )) AS sku_combined_classification
FROM wms_workstation_events_staging we
-- Handling Unit enrichment
LEFT JOIN wms_handling_units hu ON we.hu_id = hu.id
-- Storage Bin Master enrichment (using bin_id directly)
LEFT JOIN wms_storage_bin_master sbm ON we.bin_id = sbm.bin_id
-- SKU Master data
LEFT JOIN encarta_skus_master sm ON we.sku_id = sm.id
-- SKU Overrides for specific warehouse (wh_id as node_id)
LEFT JOIN encarta_skus_overrides so ON we.sku_id = so.sku_id AND we.wh_id = so.node_id AND so.active = true;