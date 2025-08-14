-- ClickHouse Materialized View for WMS Inventory Enriched
-- Enriches inventory_staging with dimension data
-- Enriches with handling_units, storage_bin, storage_bin_master, SKU data

CREATE MATERIALIZED VIEW IF NOT EXISTS wms_inventory_enriched_mv
TO wms_inventory_events_enriched
AS
SELECT
    -- Event identifiers (matching target table order)
    ie.event_id AS hu_event_id,
    ie.quant_event_id AS quant_event_id,
    ie.wh_id AS wh_id,
    
    -- Handling unit event fields
    ie.seq AS hu_event_seq,
    ie.hu_id AS hu_id,
    ie.event_type AS hu_event_type,
    ie.`timestamp` AS hu_event_timestamp,
    ie.payload AS hu_event_payload,
    ie.attrs AS hu_event_attrs,
    ie.session_id AS session_id,
    ie.task_id AS task_id,
    ie.correlation_id AS correlation_id,
    ie.storage_id AS storage_id,
    ie.outer_hu_id AS outer_hu_id,
    ie.effective_storage_id AS effective_storage_id,
    
    -- Handling unit quant event fields
    ie.sku_id AS sku_id,
    ie.uom AS uom,
    ie.bucket AS bucket,
    ie.batch AS batch,
    ie.price AS price,
    ie.inclusion_status AS inclusion_status,
    ie.locked_by_task_id AS locked_by_task_id,
    ie.lock_mode AS lock_mode,
    ie.qty_added AS qty_added,
    ie.quant_iloc AS quant_iloc,
    
    -- Enriched handling unit fields
    hu.code AS hu_code,
    hu.kindId AS hu_kind_id,
    hu.state AS hu_state,
    hu.attrs AS hu_attrs,
    hu.createdAt AS hu_created_at,
    hu.updatedAt AS hu_updated_at,
    hu.lockTaskId AS hu_lock_task_id,
    hu.effectiveStorageId AS hu_effective_storage_id,
    
    -- Handling unit kind enrichment
    huk.code AS hu_kind_code,
    huk.name AS hu_kind_name,
    huk.attrs AS hu_kind_attrs,
    huk.maxVolume AS hu_kind_max_volume,
    huk.maxWeight AS hu_kind_max_weight,
    huk.usageType AS hu_kind_usage_type,
    huk.abbr AS hu_kind_abbr,
    huk.length AS hu_kind_length,
    huk.breadth AS hu_kind_breadth,
    huk.height AS hu_kind_height,
    huk.weight AS hu_kind_weight,
    
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
    sm.principal_id AS sku_principal_id,
    
    -- SKU identifiers and tags
    if(so.identifier1 != '', so.identifier1, sm.identifier1) AS sku_identifier1,
    if(so.identifier2 != '', so.identifier2, sm.identifier2) AS sku_identifier2,
    if(so.tag1 != '', so.tag1, sm.tag1) AS sku_tag1,
    if(so.tag2 != '', so.tag2, sm.tag2) AS sku_tag2,
    if(so.tag3 != '', so.tag3, sm.tag3) AS sku_tag3,
    if(so.tag4 != '', so.tag4, sm.tag4) AS sku_tag4,
    if(so.tag5 != '', so.tag5, sm.tag5) AS sku_tag5,
    if(so.tag6 != '', so.tag6, sm.tag6) AS sku_tag6,
    if(so.tag7 != '', so.tag7, sm.tag7) AS sku_tag7,
    if(so.tag8 != '', so.tag8, sm.tag8) AS sku_tag8,
    if(so.tag9 != '', so.tag9, sm.tag9) AS sku_tag9,
    if(so.tag10 != '', so.tag10, sm.tag10) AS sku_tag10,
    
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
    )) AS sku_combined_classification,
    
    -- Storage Bin enrichment (based on effective_storage_id only)
    sbm.bin_code AS storage_bin_code,
    sbm.bin_description AS storage_bin_description,
    sbm.bin_status AS storage_bin_status,
    sbm.bin_hu_id AS storage_bin_hu_id,
    sbm.multi_sku AS storage_multi_sku,
    sbm.multi_batch AS storage_multi_batch,
    sbm.picking_position AS storage_picking_position,
    sbm.putaway_position AS storage_putaway_position,
    sbm.rank AS storage_rank,
    sbm.aisle AS storage_aisle,
    sbm.bay AS storage_bay,
    sbm.level AS storage_level,
    sbm.position AS storage_position,
    sbm.depth AS storage_depth,
    sbm.max_sku_count AS storage_max_sku_count,
    sbm.max_sku_batch_count AS storage_max_sku_batch_count,
    sbm.bin_type_id AS storage_bin_type_id,
    sbm.bin_type_code AS storage_bin_type_code,
    sbm.bin_type_description AS storage_bin_type_description,
    sbm.max_volume_in_cc AS storage_max_volume_in_cc,
    sbm.max_weight_in_kg AS storage_max_weight_in_kg,
    sbm.pallet_capacity AS storage_pallet_capacity,
    sbm.storage_hu_type AS storage_hu_type,
    sbm.auxiliary_bin AS storage_auxiliary_bin,
    sbm.hu_multi_sku AS storage_hu_multi_sku,
    sbm.hu_multi_batch AS storage_hu_multi_batch,
    sbm.use_derived_pallet_best_fit AS storage_use_derived_pallet_best_fit,
    sbm.only_full_pallet AS storage_only_full_pallet,
    sbm.zone_id AS storage_zone_id,
    sbm.zone_code AS storage_zone_code,
    sbm.zone_description AS storage_zone_description,
    sbm.zone_face AS storage_zone_face,
    sbm.peripheral AS storage_peripheral,
    sbm.surveillance_config AS storage_surveillance_config,
    sbm.area_id AS storage_area_id,
    sbm.area_code AS storage_area_code,
    sbm.area_description AS storage_area_description,
    sbm.area_type AS storage_area_type,
    sbm.rolling_days AS storage_rolling_days,
    sbm.x1 AS storage_x1,
    sbm.x2 AS storage_x2,
    sbm.y1 AS storage_y1,
    sbm.y2 AS storage_y2,
    sbm.attrs AS storage_attrs,
    sbm.bin_mapping AS storage_bin_mapping,
    
    -- Outer HU enrichment
    ohu.code AS outer_hu_code,
    ohu.kindId AS outer_hu_kind_id,
    ohu.sessionId AS outer_hu_session_id,
    ohu.taskId AS outer_hu_task_id,
    ohu.storageId AS outer_hu_storage_id,
    ohu.outerHuId AS outer_hu_outer_hu_id,
    ohu.state AS outer_hu_state,
    ohu.attrs AS outer_hu_attrs,
    ohu.lockTaskId AS outer_hu_lock_task_id,
    
    -- Outer HU kind enrichment
    ohuk.code AS outer_hu_kind_code,
    ohuk.name AS outer_hu_kind_name,
    ohuk.attrs AS outer_hu_kind_attrs,
    ohuk.maxVolume AS outer_hu_kind_max_volume,
    ohuk.maxWeight AS outer_hu_kind_max_weight,
    ohuk.usageType AS outer_hu_kind_usage_type,
    ohuk.abbr AS outer_hu_kind_abbr,
    ohuk.length AS outer_hu_kind_length,
    ohuk.breadth AS outer_hu_kind_breadth,
    ohuk.height AS outer_hu_kind_height,
    ohuk.weight AS outer_hu_kind_weight
FROM wms_inventory_events_staging ie
-- Handling Unit enrichment
LEFT JOIN wms_handling_units hu ON ie.hu_id = hu.id
LEFT JOIN wms_handling_unit_kinds huk ON hu.kindId = huk.id
-- Storage Bin Master enrichment (using effective_storage_id as bin_id)
LEFT JOIN wms_storage_bin_master sbm ON ie.effective_storage_id = sbm.bin_id
-- Outer HU enrichment
LEFT JOIN wms_handling_units ohu ON ie.outer_hu_id = ohu.id
LEFT JOIN wms_handling_unit_kinds ohuk ON ohu.kindId = ohuk.id
-- SKU Master data
LEFT JOIN encarta_skus_master sm ON ie.sku_id = sm.id
-- SKU Overrides for specific warehouse (wh_id as node_id)
LEFT JOIN encarta_skus_overrides so ON ie.sku_id = so.sku_id AND ie.wh_id = so.node_id AND so.active = true;