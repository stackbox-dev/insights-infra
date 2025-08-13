-- Backfill script for WMS Workstation Events Enriched table
-- Use this script to manually populate historical data if MV was created without POPULATE
-- or to re-process specific date ranges

-- Check current data status
SELECT 'Staging table count:' AS metric, count(*) AS value FROM wms_workstation_events_staging
UNION ALL
SELECT 'Enriched table count:', count(*) FROM wms_workstation_events_enriched
UNION ALL
SELECT 'Latest staging timestamp:', max(event_timestamp) FROM wms_workstation_events_staging
UNION ALL
SELECT 'Latest enriched timestamp:', max(event_timestamp) FROM wms_workstation_events_enriched;

-- Backfill all historical data (use with caution on large tables)
INSERT INTO wms_workstation_events_enriched
SELECT
    -- Core fields from staging
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
    
    -- Handling Unit enrichment
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
    
    -- Storage Bin Master enrichment
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
    
    -- SKU enrichment with overrides
    COALESCE(so.code, sm.code, '') AS sku_code,
    COALESCE(so.name, sm.name, '') AS sku_name,
    COALESCE(so.short_description, sm.short_description, '') AS sku_short_description,
    COALESCE(so.description, sm.description, '') AS sku_description,
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
    
    -- SKU identifiers and tags
    COALESCE(so.identifier1, sm.identifier1, '') AS sku_identifier1,
    COALESCE(so.identifier2, sm.identifier2, '') AS sku_identifier2,
    COALESCE(so.tag1, sm.tag1, '') AS sku_tag1,
    COALESCE(so.tag2, sm.tag2, '') AS sku_tag2,
    COALESCE(so.tag3, sm.tag3, '') AS sku_tag3,
    COALESCE(so.tag4, sm.tag4, '') AS sku_tag4,
    COALESCE(so.tag5, sm.tag5, '') AS sku_tag5,
    
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
    sm.combined_classification AS sku_combined_classification
FROM wms_workstation_events_staging we
LEFT JOIN wms_handling_units hu ON we.hu_id = hu.id
LEFT JOIN wms_storage_bin_master sbm ON we.bin_id = sbm.bin_id
LEFT JOIN encarta_skus_master sm ON we.sku_id = sm.id
LEFT JOIN encarta_skus_overrides so ON we.sku_id = so.sku_id AND we.wh_id = so.node_id
-- Uncomment and modify date range as needed:
-- WHERE we.event_timestamp >= '2024-01-01' AND we.event_timestamp < '2025-01-01'
;

-- Verify backfill completion
SELECT 'After backfill - Enriched count:' AS metric, count(*) AS value FROM wms_workstation_events_enriched;