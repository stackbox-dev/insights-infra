-- StarRocks Async Materialized View: encarta_skus_combined_mv
--
-- PURPOSE:
--   Pre-computes the encarta_skus_combined JOIN for faster query performance.
--   StarRocks Async MVs support automatic query rewriting — queries against
--   encarta_skus_master + encarta_skus_overrides may automatically use this MV.
--
-- HOW THIS DIFFERS FROM CLICKHOUSE MVs:
--   ClickHouse MV: Triggers on EVERY insert, enriches data immediately at write time.
--   StarRocks Async MV: Refreshes in BATCH on a schedule. NOT real-time.
--
-- WHEN TO USE:
--   Use this MV for dashboards and reports that query SKU combined data frequently.
--   For real-time enrichment (e.g. pick-drop events), JOIN at query time instead:
--     SELECT pd.*, sku.name FROM wms_pick_drop pd
--     LEFT JOIN encarta_skus_combined sku ON pd.sku_id = sku.sku_id AND sku.node_id = pd.wh_id;
--
-- REFRESH: Manual or scheduled. Run after bulk SKU data changes.
--   REFRESH MATERIALIZED VIEW encarta_skus_combined_mv;

CREATE MATERIALIZED VIEW IF NOT EXISTS encarta_skus_combined_mv
REFRESH ASYNC
PROPERTIES (
    "replication_num" = "1"
)
AS
SELECT
    sm.id AS sku_id,
    so.node_id AS node_id,
    sm.principal_id AS principal_id,
    sm.category AS category,
    sm.product AS product,
    sm.product_id AS product_id,
    sm.category_group AS category_group,
    sm.sub_brand AS sub_brand,
    sm.brand AS brand,
    sm.code AS code,
    COALESCE(so.name, sm.name) AS name,
    COALESCE(so.short_description, sm.short_description) AS short_description,
    COALESCE(so.description, sm.description) AS description,
    COALESCE(so.fulfillment_type, sm.fulfillment_type) AS fulfillment_type,
    COALESCE(so.avg_l0_per_put, sm.avg_l0_per_put) AS avg_l0_per_put,
    COALESCE(so.inventory_type, sm.inventory_type) AS inventory_type,
    COALESCE(so.shelf_life, sm.shelf_life) AS shelf_life,
    COALESCE(so.identifier1, sm.identifier1) AS identifier1,
    COALESCE(so.identifier2, sm.identifier2) AS identifier2,
    COALESCE(so.tag1, sm.tag1) AS tag1,
    COALESCE(so.tag2, sm.tag2) AS tag2,
    COALESCE(so.tag3, sm.tag3) AS tag3,
    COALESCE(so.tag4, sm.tag4) AS tag4,
    COALESCE(so.tag5, sm.tag5) AS tag5,
    COALESCE(so.tag6, sm.tag6) AS tag6,
    COALESCE(so.tag7, sm.tag7) AS tag7,
    COALESCE(so.tag8, sm.tag8) AS tag8,
    COALESCE(so.tag9, sm.tag9) AS tag9,
    COALESCE(so.tag10, sm.tag10) AS tag10,
    COALESCE(so.handling_unit_type, sm.handling_unit_type) AS handling_unit_type,
    COALESCE(so.cases_per_layer, sm.cases_per_layer) AS cases_per_layer,
    COALESCE(so.layers, sm.layers) AS layers,
    COALESCE(so.active_from, sm.active_from) AS active_from,
    COALESCE(so.active_till, sm.active_till) AS active_till,
    COALESCE(so.l0_units, sm.l0_units) AS l0_units,
    COALESCE(so.l1_units, sm.l1_units) AS l1_units,
    COALESCE(so.l2_units, sm.l2_units) AS l2_units,
    COALESCE(so.l3_units, sm.l3_units) AS l3_units,
    COALESCE(so.l0_name, sm.l0_name) AS l0_name,
    COALESCE(so.l0_weight, sm.l0_weight) AS l0_weight,
    COALESCE(so.l0_volume, sm.l0_volume) AS l0_volume,
    COALESCE(so.l0_package_type, sm.l0_package_type) AS l0_package_type,
    COALESCE(so.l0_length, sm.l0_length) AS l0_length,
    COALESCE(so.l0_width, sm.l0_width) AS l0_width,
    COALESCE(so.l0_height, sm.l0_height) AS l0_height,
    COALESCE(so.l0_packing_efficiency, sm.l0_packing_efficiency) AS l0_packing_efficiency,
    COALESCE(so.l0_itf_code, sm.l0_itf_code) AS l0_itf_code,
    COALESCE(so.l0_erp_weight, sm.l0_erp_weight) AS l0_erp_weight,
    COALESCE(so.l0_erp_volume, sm.l0_erp_volume) AS l0_erp_volume,
    COALESCE(so.l0_erp_length, sm.l0_erp_length) AS l0_erp_length,
    COALESCE(so.l0_erp_width, sm.l0_erp_width) AS l0_erp_width,
    COALESCE(so.l0_erp_height, sm.l0_erp_height) AS l0_erp_height,
    COALESCE(so.l0_text_tag1, sm.l0_text_tag1) AS l0_text_tag1,
    COALESCE(so.l0_text_tag2, sm.l0_text_tag2) AS l0_text_tag2,
    COALESCE(so.l0_image, sm.l0_image) AS l0_image,
    COALESCE(so.l0_num_tag1, sm.l0_num_tag1) AS l0_num_tag1,
    COALESCE(so.l1_name, sm.l1_name) AS l1_name,
    COALESCE(so.l1_weight, sm.l1_weight) AS l1_weight,
    COALESCE(so.l1_volume, sm.l1_volume) AS l1_volume,
    COALESCE(so.l1_package_type, sm.l1_package_type) AS l1_package_type,
    COALESCE(so.l1_length, sm.l1_length) AS l1_length,
    COALESCE(so.l1_width, sm.l1_width) AS l1_width,
    COALESCE(so.l1_height, sm.l1_height) AS l1_height,
    COALESCE(so.l1_packing_efficiency, sm.l1_packing_efficiency) AS l1_packing_efficiency,
    COALESCE(so.l1_itf_code, sm.l1_itf_code) AS l1_itf_code,
    COALESCE(so.l1_erp_weight, sm.l1_erp_weight) AS l1_erp_weight,
    COALESCE(so.l1_erp_volume, sm.l1_erp_volume) AS l1_erp_volume,
    COALESCE(so.l1_erp_length, sm.l1_erp_length) AS l1_erp_length,
    COALESCE(so.l1_erp_width, sm.l1_erp_width) AS l1_erp_width,
    COALESCE(so.l1_erp_height, sm.l1_erp_height) AS l1_erp_height,
    COALESCE(so.l1_text_tag1, sm.l1_text_tag1) AS l1_text_tag1,
    COALESCE(so.l1_text_tag2, sm.l1_text_tag2) AS l1_text_tag2,
    COALESCE(so.l1_image, sm.l1_image) AS l1_image,
    COALESCE(so.l1_num_tag1, sm.l1_num_tag1) AS l1_num_tag1,
    COALESCE(so.l2_name, sm.l2_name) AS l2_name,
    COALESCE(so.l2_weight, sm.l2_weight) AS l2_weight,
    COALESCE(so.l2_volume, sm.l2_volume) AS l2_volume,
    COALESCE(so.l2_package_type, sm.l2_package_type) AS l2_package_type,
    COALESCE(so.l2_length, sm.l2_length) AS l2_length,
    COALESCE(so.l2_width, sm.l2_width) AS l2_width,
    COALESCE(so.l2_height, sm.l2_height) AS l2_height,
    COALESCE(so.l2_packing_efficiency, sm.l2_packing_efficiency) AS l2_packing_efficiency,
    COALESCE(so.l2_itf_code, sm.l2_itf_code) AS l2_itf_code,
    COALESCE(so.l2_erp_weight, sm.l2_erp_weight) AS l2_erp_weight,
    COALESCE(so.l2_erp_volume, sm.l2_erp_volume) AS l2_erp_volume,
    COALESCE(so.l2_erp_length, sm.l2_erp_length) AS l2_erp_length,
    COALESCE(so.l2_erp_width, sm.l2_erp_width) AS l2_erp_width,
    COALESCE(so.l2_erp_height, sm.l2_erp_height) AS l2_erp_height,
    COALESCE(so.l2_text_tag1, sm.l2_text_tag1) AS l2_text_tag1,
    COALESCE(so.l2_text_tag2, sm.l2_text_tag2) AS l2_text_tag2,
    COALESCE(so.l2_image, sm.l2_image) AS l2_image,
    COALESCE(so.l2_num_tag1, sm.l2_num_tag1) AS l2_num_tag1,
    COALESCE(so.l3_name, sm.l3_name) AS l3_name,
    COALESCE(so.l3_weight, sm.l3_weight) AS l3_weight,
    COALESCE(so.l3_volume, sm.l3_volume) AS l3_volume,
    COALESCE(so.l3_package_type, sm.l3_package_type) AS l3_package_type,
    COALESCE(so.l3_length, sm.l3_length) AS l3_length,
    COALESCE(so.l3_width, sm.l3_width) AS l3_width,
    COALESCE(so.l3_height, sm.l3_height) AS l3_height,
    COALESCE(so.l3_packing_efficiency, sm.l3_packing_efficiency) AS l3_packing_efficiency,
    COALESCE(so.l3_itf_code, sm.l3_itf_code) AS l3_itf_code,
    COALESCE(so.l3_erp_weight, sm.l3_erp_weight) AS l3_erp_weight,
    COALESCE(so.l3_erp_volume, sm.l3_erp_volume) AS l3_erp_volume,
    COALESCE(so.l3_erp_length, sm.l3_erp_length) AS l3_erp_length,
    COALESCE(so.l3_erp_width, sm.l3_erp_width) AS l3_erp_width,
    COALESCE(so.l3_erp_height, sm.l3_erp_height) AS l3_erp_height,
    COALESCE(so.l3_text_tag1, sm.l3_text_tag1) AS l3_text_tag1,
    COALESCE(so.l3_text_tag2, sm.l3_text_tag2) AS l3_text_tag2,
    COALESCE(so.l3_image, sm.l3_image) AS l3_image,
    COALESCE(so.l3_num_tag1, sm.l3_num_tag1) AS l3_num_tag1,
    COALESCE(so.active, sm.active) AS active,
    COALESCE(so.classifications, sm.classifications) AS classifications,
    COALESCE(so.product_classifications, sm.product_classifications) AS product_classifications,
    CASE WHEN so.sku_id IS NOT NULL THEN true ELSE false END AS has_override,
    GREATEST(
        COALESCE(so.updated_at, '1970-01-01 00:00:00'),
        COALESCE(sm.updated_at, '1970-01-01 00:00:00')
    ) AS updated_at
FROM encarta_skus_master sm
LEFT JOIN encarta_skus_overrides so
    ON sm.id = so.sku_id
    AND so.active = true
WHERE sm.active = true;
