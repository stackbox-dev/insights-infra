-- One-time backfill script: populate wms_pick_drop_enriched from existing wms_pick_drop_staging rows
-- Run ONCE after creating the wms_pick_drop_enriched table, BEFORE starting the Flink pipeline
--
-- NOTE: This uses CURRENT SKU/worker/HU data (not point-in-time historical values)
--   → Best approximation for historical rows: SKU attributes at time of backfill
--   → Going forward, the Flink pipeline captures true point-in-time snapshots
--
-- PREREQUISITES:
--   1. wms_pick_drop_enriched table must exist (run pick-drop-enriched.sql first)
--   2. encarta_skus_master must be populated (StarRocks connector running)
--   3. wms_workers must be populated (StarRocks connector running)
--   4. wms_handling_units must be populated (StarRocks connector running)
--
-- USAGE (run on StarRocks dc-prod via mysql client):
--   kubectl exec -it -n starrocks --context SbxDCProdCluster kube-starrocks-fe-0 -- \
--     mysql -h 127.0.0.1 -P 9030 -u root -pStarRocks@2026 prod \
--     -e "SOURCE XX-backfill-pick-drop-enriched.sql"
--
-- EXPECTED DURATION: ~5-10 minutes for 1.7M rows (StarRocks parallel INSERT)
-- EXPECTED ROW COUNT: should match SELECT COUNT(*) FROM wms_pick_drop_staging

INSERT INTO wms_pick_drop_enriched
SELECT
    -- Core Identifiers
    pb.pick_item_id,
    pb.drop_item_id,
    pb.pick_item_created_at,
    pb.wh_id,
    sm.principal_id AS principal_id,
    pb.session_id,
    pb.task_id,
    pb.lm_trip_id,

    -- Pick Item Core Fields
    pb.picked_bin,
    pb.picked_sku_id,
    pb.picked_batch,
    pb.picked_uom,
    pb.overall_qty,
    pb.qty,
    pb.hu_code,
    pb.destination_bin_code,
    pb.picked_qty,
    pb.picked_at,
    pb.picked_by_worker_id,
    pb.moved_at,
    pb.processed_at,

    -- Pick Handling Unit Fields
    pb.picked_hu_eq_uom,
    pb.picked_has_inner_hus,
    pb.picked_inner_hu_eq_uom,
    pb.picked_bin_assigned_at,
    pb.scan_source_hu_kind,
    pb.pick_source_hu_kind,
    pb.carrier_hu_kind,
    pb.scanned_source_hu_code,
    pb.picked_source_hu_code,
    pb.carrier_hu_code,
    pb.hu_kind,
    pb.source_hu_eq_uom,
    pb.pick_item_updated_at,

    -- Pick Additional Fields
    pb.eligible_drop_locations,
    pb.parent_item_id,
    pb.old_batch,
    pb.dest_bucket,
    pb.original_source_bin_code,
    pb.picked_inner_hu_code,
    pb.picked_inner_hu_kind_code,
    pb.picked_quant_bucket,
    pb.pick_auto_complete,
    pb.pick_hu,
    pb.short_allocation_reason,
    pb.pd_previous_task_id AS drop_item_previous_task_id,

    -- Drop Item Core Fields
    pb.dropped_sku_id,
    pb.dropped_batch,
    pb.dropped_uom,
    pb.drop_bucket,
    pb.picked_hu_code,
    pb.dropped_bin_code,
    pb.dropped_qty,
    pb.dropped_at,
    pb.drop_item_updated_at,

    -- Drop Handling Unit Fields
    pb.drop_hu_in_bin,
    pb.scan_dest_hu,
    pb.allow_hu_break,
    pb.dropped_has_inner_hus,
    pb.scan_inner_hus,
    pb.dropped_hu_eq_uom,
    pb.dest_hu_code,
    pb.dropped_inner_hu_id,
    pb.dropped_inner_hu_eq_uom,
    pb.dest_bin_assigned_at,
    pb.drop_uom,
    pb.drop_parent_item_id,
    pb.hu_broken,
    pb.drop_original_source_bin_code,
    pb.processed_for_loading_at,
    pb.drop_quant_bucket,
    pb.drop_inner_hu_code,
    pb.dropped_inner_hu_kind_code,
    pb.drop_inner_hu,
    pb.allow_inner_hu_break,
    pb.inner_hu_broken,
    pb.drop_auto_complete,
    pb.quant_slotting_for_hus,
    pb.processed_on_drop_at,
    pb.allow_hu_break_v2,

    -- Additional Pick Item IDs
    pb.bin_id,
    pb.bin_hu_id,
    pb.destination_bin_id,
    pb.destination_bin_hu_id,
    pb.pick_deactivated_at,
    pb.pick_deactivated_by,
    pb.moved_by,
    pb.scanned_source_hu_id,
    pb.picked_source_hu_id,
    pb.carrier_hu_id,
    pb.original_source_bin_id,
    pb.inner_hu_id,
    pb.inner_hu_kind_id,
    pb.pd_previous_task_id,
    pb.input_source_bin_id,
    pb.provisional_item_id,
    pb.input_dest_hu_id,
    pb.pick_item_kind,
    pb.tp_assigned_at,
    pb.leg_index,
    pb.last_leg,
    pb.ep_assigned_at,
    pb.carrier_hu_formed_id,
    pb.hu_index,
    pb.pick_sequence,
    pb.carrier_hu_force_closed,
    pb.input_dest_bin_id,
    pb.inner_hu_index,
    pb.inner_carrier_hu_key,
    pb.inner_carrier_hu_formed_id,
    pb.inner_carrier_hu_id,
    pb.inner_carrier_hu_code,
    pb.inner_carrier_hu_kind,
    pb.induction_id,
    pb.inner_carrier_hu_force_closed,
    pb.mhe_id,
    pb.pick_attrs,
    pb.iloc,
    pb.dest_iloc,

    -- Additional Drop Item IDs
    pb.source_bin_id,
    pb.source_bin_hu_id,
    pb.drop_bin_id,
    pb.drop_bin_hu_id,
    pb.drop_created_at,
    pb.drop_deactivated_at,
    pb.drop_deactivated_by,
    pb.dropped_by_worker_id,
    pb.dest_hu_id,
    pb.source_bucket,
    pb.original_destination_bin_id,
    pb.drop_lm_trip_id,
    pb.processed_for_pick_at,
    pb.drop_provisional_item_id,
    pb.drop_input_dest_hu_id,
    pb.drop_leg_index,
    pb.drop_last_leg,
    pb.drop_input_dest_bin_id,
    pb.drop_induction_id,
    pb.drop_attrs,
    pb.drop_mhe_id,
    pb.drop_iloc,
    pb.source_iloc,

    -- Mapping Fields
    pb.mapping_id,
    pb.mapping_created_at,

    -- Event time
    pb.event_time,

    -- Worker Enrichment (current worker data — best approximation for historical backfill)
    w.code AS worker_code,
    w.name AS worker_name,
    w.phone AS worker_phone,
    w.supervisor AS worker_supervisor,
    w.active AS worker_active,

    -- Dropped Handling Unit Enrichment (current HU data)
    hu.code AS dropped_hu_code,
    hu.kindId AS dropped_hu_kind_id,
    hu.sessionId AS dropped_hu_session_id,
    hu.taskId AS dropped_hu_task_id,
    hu.storageId AS dropped_hu_storage_id,
    hu.outerHuId AS dropped_hu_outer_hu_id,
    hu.state AS dropped_hu_state,
    hu.attrs AS dropped_hu_attrs,
    hu.lockTaskId AS dropped_hu_lock_task_id,
    hu.effectiveStorageId AS dropped_hu_effective_storage_id,
    hu.createdAt AS dropped_hu_created_at,
    hu.updatedAt AS dropped_hu_updated_at,

    -- SKU Enrichment (current SKU data from encarta_skus_master + overrides)
    -- Join directly on picked_sku_id; apply override logic inline
    sm.category AS sku_category,
    sm.product AS sku_product,
    sm.product_id AS sku_product_id,
    sm.category_group AS sku_category_group,
    sm.sub_brand AS sku_sub_brand,
    sm.brand AS sku_brand,
    sm.code AS sku_code,   -- always from master, never overridden
    COALESCE(NULLIF(so.name, ''), sm.name) AS sku_name,
    COALESCE(NULLIF(so.short_description, ''), sm.short_description) AS sku_short_description,
    COALESCE(NULLIF(so.description, ''), sm.description) AS sku_description,
    COALESCE(NULLIF(so.fulfillment_type, ''), sm.fulfillment_type) AS sku_fulfillment_type,
    sm.inventory_type AS sku_inventory_type,
    COALESCE(NULLIF(so.shelf_life, 0), sm.shelf_life) AS sku_shelf_life,
    COALESCE(NULLIF(so.tag1, ''), sm.tag1) AS sku_tag1,
    COALESCE(NULLIF(so.tag2, ''), sm.tag2) AS sku_tag2,
    COALESCE(NULLIF(so.tag3, ''), sm.tag3) AS sku_tag3,
    COALESCE(NULLIF(so.tag4, ''), sm.tag4) AS sku_tag4,
    COALESCE(NULLIF(so.tag5, ''), sm.tag5) AS sku_tag5,
    COALESCE(NULLIF(so.handling_unit_type, ''), sm.handling_unit_type) AS sku_handling_unit_type,
    COALESCE(NULLIF(so.cases_per_layer, 0), sm.cases_per_layer) AS sku_cases_per_layer,
    COALESCE(NULLIF(so.layers, 0), sm.layers) AS sku_layers,
    sm.l0_units AS sku_l0_units,
    sm.l1_units AS sku_l1_units,
    COALESCE(NULLIF(so.l2_units, 0), sm.l2_units) AS sku_l2_units,
    COALESCE(NULLIF(so.l3_units, 0), sm.l3_units) AS sku_l3_units,
    sm.l0_name AS sku_l0_name,
    sm.l0_weight AS sku_l0_weight,
    sm.l0_volume AS sku_l0_volume,
    sm.l0_package_type AS sku_l0_package_type,
    sm.l0_length AS sku_l0_length,
    sm.l0_width AS sku_l0_width,
    sm.l0_height AS sku_l0_height,
    sm.l0_itf_code AS sku_l0_itf_code,
    sm.l1_name AS sku_l1_name,
    sm.l1_weight AS sku_l1_weight,
    sm.l1_volume AS sku_l1_volume,
    sm.l1_package_type AS sku_l1_package_type,
    sm.l1_length AS sku_l1_length,
    sm.l1_width AS sku_l1_width,
    sm.l1_height AS sku_l1_height,
    sm.l1_itf_code AS sku_l1_itf_code,
    sm.l2_name AS sku_l2_name,
    sm.l2_weight AS sku_l2_weight,
    sm.l2_volume AS sku_l2_volume,
    sm.l2_package_type AS sku_l2_package_type,
    sm.l2_length AS sku_l2_length,
    sm.l2_width AS sku_l2_width,
    sm.l2_height AS sku_l2_height,
    sm.l2_itf_code AS sku_l2_itf_code,
    sm.l3_name AS sku_l3_name,
    sm.l3_weight AS sku_l3_weight,
    sm.l3_volume AS sku_l3_volume,
    sm.l3_package_type AS sku_l3_package_type,
    sm.l3_length AS sku_l3_length,
    sm.l3_width AS sku_l3_width,
    sm.l3_height AS sku_l3_height,
    sm.l3_itf_code AS sku_l3_itf_code,
    COALESCE(NULLIF(so.avg_l0_per_put, 0), sm.avg_l0_per_put) AS sku_avg_l0_per_put,
    NULL AS sku_combined_classification  -- not computed in backfill; Flink pipeline handles going forward

FROM wms_pick_drop_staging pb

-- Worker enrichment: join on picked_by_worker_id
LEFT JOIN wms_workers w ON pb.picked_by_worker_id = w.id

-- HU enrichment: join on dropped_inner_hu_id
LEFT JOIN wms_handling_units hu ON pb.dropped_inner_hu_id = hu.id

-- SKU master data (product hierarchy + UOM dimensions from encarta pipeline)
LEFT JOIN encarta_skus_master sm ON pb.picked_sku_id = sm.id

-- SKU node-specific overrides for the warehouse
-- Full override fields available in StarRocks encarta_skus_overrides table
LEFT JOIN encarta_skus_overrides so
    ON pb.picked_sku_id = so.sku_id
    AND pb.wh_id = so.node_id
    AND so.active = true

-- Only backfill real events (not tombstones/null events)
WHERE pb.event_time > '1970-01-01 00:00:00';

-- Verification queries (run after backfill):
-- 1. Row count should match staging:
--    SELECT COUNT(*) FROM wms_pick_drop_enriched;
--    SELECT COUNT(*) FROM wms_pick_drop_staging;
--
-- 2. Check SKU data is populated:
--    SELECT pick_item_id, picked_sku_id, sku_name, sku_code, sku_brand
--    FROM wms_pick_drop_enriched
--    WHERE sku_name IS NOT NULL
--    LIMIT 5;
--
-- 3. Check worker data is populated:
--    SELECT pick_item_id, picked_by_worker_id, worker_name, worker_code
--    FROM wms_pick_drop_enriched
--    WHERE worker_name IS NOT NULL
--    LIMIT 5;
--
-- 4. SKU enrichment coverage (% of rows with SKU data):
--    SELECT
--        COUNT(*) AS total_rows,
--        COUNT(sku_name) AS rows_with_sku,
--        ROUND(COUNT(sku_name) * 100.0 / COUNT(*), 1) AS sku_coverage_pct
--    FROM wms_pick_drop_enriched;
