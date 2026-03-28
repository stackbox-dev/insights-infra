-- ClickHouse Parameterized View for Combined SKU Data
-- Combines SKU master data with node-specific overrides
-- Uses parameterized view to efficiently query by node_id

CREATE VIEW IF NOT EXISTS encarta_skus_combined AS
SELECT 
    -- SKU Identifiers
    sm.id AS sku_id,
    {node_id:Int64} AS node_id,
    
    -- Principal ID (always from master, never overridden)
    sm.principal_id AS principal_id,
    
    -- Product Hierarchy (always from master, never overridden)
    sm.category AS category,
    sm.product AS product,
    sm.product_id AS product_id,
    sm.category_group AS category_group,
    sm.sub_brand AS sub_brand,
    sm.brand AS brand,
    
    -- SKU Basic Information
    sm.code AS code,  -- Code is never overridden, always from master
    if(so.name != '', so.name, sm.name) AS name,
    if(so.short_description != '', so.short_description, sm.short_description) AS short_description,
    if(so.description != '', so.description, sm.description) AS description,
    if(so.fulfillment_type != '', so.fulfillment_type, sm.fulfillment_type) AS fulfillment_type,
    if(so.avg_l0_per_put != 0, so.avg_l0_per_put, sm.avg_l0_per_put) AS avg_l0_per_put,
    if(so.inventory_type != '', so.inventory_type, sm.inventory_type) AS inventory_type,
    if(so.shelf_life != 0, so.shelf_life, sm.shelf_life) AS shelf_life,
    
    -- SKU Identifiers
    if(so.identifier1 != '', so.identifier1, sm.identifier1) AS identifier1,
    if(so.identifier2 != '', so.identifier2, sm.identifier2) AS identifier2,
    
    -- SKU Tags
    if(so.tag1 != '', so.tag1, sm.tag1) AS tag1,
    if(so.tag2 != '', so.tag2, sm.tag2) AS tag2,
    if(so.tag3 != '', so.tag3, sm.tag3) AS tag3,
    if(so.tag4 != '', so.tag4, sm.tag4) AS tag4,
    if(so.tag5 != '', so.tag5, sm.tag5) AS tag5,
    if(so.tag6 != '', so.tag6, sm.tag6) AS tag6,
    if(so.tag7 != '', so.tag7, sm.tag7) AS tag7,
    if(so.tag8 != '', so.tag8, sm.tag8) AS tag8,
    if(so.tag9 != '', so.tag9, sm.tag9) AS tag9,
    if(so.tag10 != '', so.tag10, sm.tag10) AS tag10,
    
    -- Packaging Configuration
    if(so.handling_unit_type != '', so.handling_unit_type, sm.handling_unit_type) AS handling_unit_type,
    if(so.cases_per_layer != 0, so.cases_per_layer, sm.cases_per_layer) AS cases_per_layer,
    if(so.layers != 0, so.layers, sm.layers) AS layers,
    
    -- Activity Period
    if(so.active_from != toDateTime64('1970-01-01 00:00:00', 3), so.active_from, sm.active_from) AS active_from,
    if(so.active_till != toDateTime64('1970-01-01 00:00:00', 3), so.active_till, sm.active_till) AS active_till,
    
    -- Unit of Measure Hierarchy
    if(so.l0_units != 0, so.l0_units, sm.l0_units) AS l0_units,
    if(so.l1_units != 0, so.l1_units, sm.l1_units) AS l1_units,
    if(so.l2_units != 0, so.l2_units, sm.l2_units) AS l2_units,
    if(so.l3_units != 0, so.l3_units, sm.l3_units) AS l3_units,
    
    -- L0 (Base Unit) Specifications
    if(so.l0_name != '', so.l0_name, sm.l0_name) AS l0_name,
    if(so.l0_weight != 0, so.l0_weight, sm.l0_weight) AS l0_weight,
    if(so.l0_volume != 0, so.l0_volume, sm.l0_volume) AS l0_volume,
    if(so.l0_package_type != '', so.l0_package_type, sm.l0_package_type) AS l0_package_type,
    if(so.l0_length != 0, so.l0_length, sm.l0_length) AS l0_length,
    if(so.l0_width != 0, so.l0_width, sm.l0_width) AS l0_width,
    if(so.l0_height != 0, so.l0_height, sm.l0_height) AS l0_height,
    if(so.l0_packing_efficiency != 0, so.l0_packing_efficiency, sm.l0_packing_efficiency) AS l0_packing_efficiency,
    if(so.l0_itf_code != '', so.l0_itf_code, sm.l0_itf_code) AS l0_itf_code,
    if(so.l0_erp_weight != 0, so.l0_erp_weight, sm.l0_erp_weight) AS l0_erp_weight,
    if(so.l0_erp_volume != 0, so.l0_erp_volume, sm.l0_erp_volume) AS l0_erp_volume,
    if(so.l0_erp_length != 0, so.l0_erp_length, sm.l0_erp_length) AS l0_erp_length,
    if(so.l0_erp_width != 0, so.l0_erp_width, sm.l0_erp_width) AS l0_erp_width,
    if(so.l0_erp_height != 0, so.l0_erp_height, sm.l0_erp_height) AS l0_erp_height,
    if(so.l0_text_tag1 != '', so.l0_text_tag1, sm.l0_text_tag1) AS l0_text_tag1,
    if(so.l0_text_tag2 != '', so.l0_text_tag2, sm.l0_text_tag2) AS l0_text_tag2,
    if(so.l0_image != '', so.l0_image, sm.l0_image) AS l0_image,
    if(so.l0_num_tag1 != 0, so.l0_num_tag1, sm.l0_num_tag1) AS l0_num_tag1,
    
    -- L1 Unit Specifications
    if(so.l1_name != '', so.l1_name, sm.l1_name) AS l1_name,
    if(so.l1_weight != 0, so.l1_weight, sm.l1_weight) AS l1_weight,
    if(so.l1_volume != 0, so.l1_volume, sm.l1_volume) AS l1_volume,
    if(so.l1_package_type != '', so.l1_package_type, sm.l1_package_type) AS l1_package_type,
    if(so.l1_length != 0, so.l1_length, sm.l1_length) AS l1_length,
    if(so.l1_width != 0, so.l1_width, sm.l1_width) AS l1_width,
    if(so.l1_height != 0, so.l1_height, sm.l1_height) AS l1_height,
    if(so.l1_packing_efficiency != 0, so.l1_packing_efficiency, sm.l1_packing_efficiency) AS l1_packing_efficiency,
    if(so.l1_itf_code != '', so.l1_itf_code, sm.l1_itf_code) AS l1_itf_code,
    if(so.l1_erp_weight != 0, so.l1_erp_weight, sm.l1_erp_weight) AS l1_erp_weight,
    if(so.l1_erp_volume != 0, so.l1_erp_volume, sm.l1_erp_volume) AS l1_erp_volume,
    if(so.l1_erp_length != 0, so.l1_erp_length, sm.l1_erp_length) AS l1_erp_length,
    if(so.l1_erp_width != 0, so.l1_erp_width, sm.l1_erp_width) AS l1_erp_width,
    if(so.l1_erp_height != 0, so.l1_erp_height, sm.l1_erp_height) AS l1_erp_height,
    if(so.l1_text_tag1 != '', so.l1_text_tag1, sm.l1_text_tag1) AS l1_text_tag1,
    if(so.l1_text_tag2 != '', so.l1_text_tag2, sm.l1_text_tag2) AS l1_text_tag2,
    if(so.l1_image != '', so.l1_image, sm.l1_image) AS l1_image,
    if(so.l1_num_tag1 != 0, so.l1_num_tag1, sm.l1_num_tag1) AS l1_num_tag1,
    
    -- L2 Unit Specifications
    if(so.l2_name != '', so.l2_name, sm.l2_name) AS l2_name,
    if(so.l2_weight != 0, so.l2_weight, sm.l2_weight) AS l2_weight,
    if(so.l2_volume != 0, so.l2_volume, sm.l2_volume) AS l2_volume,
    if(so.l2_package_type != '', so.l2_package_type, sm.l2_package_type) AS l2_package_type,
    if(so.l2_length != 0, so.l2_length, sm.l2_length) AS l2_length,
    if(so.l2_width != 0, so.l2_width, sm.l2_width) AS l2_width,
    if(so.l2_height != 0, so.l2_height, sm.l2_height) AS l2_height,
    if(so.l2_packing_efficiency != 0, so.l2_packing_efficiency, sm.l2_packing_efficiency) AS l2_packing_efficiency,
    if(so.l2_itf_code != '', so.l2_itf_code, sm.l2_itf_code) AS l2_itf_code,
    if(so.l2_erp_weight != 0, so.l2_erp_weight, sm.l2_erp_weight) AS l2_erp_weight,
    if(so.l2_erp_volume != 0, so.l2_erp_volume, sm.l2_erp_volume) AS l2_erp_volume,
    if(so.l2_erp_length != 0, so.l2_erp_length, sm.l2_erp_length) AS l2_erp_length,
    if(so.l2_erp_width != 0, so.l2_erp_width, sm.l2_erp_width) AS l2_erp_width,
    if(so.l2_erp_height != 0, so.l2_erp_height, sm.l2_erp_height) AS l2_erp_height,
    if(so.l2_text_tag1 != '', so.l2_text_tag1, sm.l2_text_tag1) AS l2_text_tag1,
    if(so.l2_text_tag2 != '', so.l2_text_tag2, sm.l2_text_tag2) AS l2_text_tag2,
    if(so.l2_image != '', so.l2_image, sm.l2_image) AS l2_image,
    if(so.l2_num_tag1 != 0, so.l2_num_tag1, sm.l2_num_tag1) AS l2_num_tag1,
    
    -- L3 Unit Specifications
    if(so.l3_name != '', so.l3_name, sm.l3_name) AS l3_name,
    if(so.l3_weight != 0, so.l3_weight, sm.l3_weight) AS l3_weight,
    if(so.l3_volume != 0, so.l3_volume, sm.l3_volume) AS l3_volume,
    if(so.l3_package_type != '', so.l3_package_type, sm.l3_package_type) AS l3_package_type,
    if(so.l3_length != 0, so.l3_length, sm.l3_length) AS l3_length,
    if(so.l3_width != 0, so.l3_width, sm.l3_width) AS l3_width,
    if(so.l3_height != 0, so.l3_height, sm.l3_height) AS l3_height,
    if(so.l3_packing_efficiency != 0, so.l3_packing_efficiency, sm.l3_packing_efficiency) AS l3_packing_efficiency,
    if(so.l3_itf_code != '', so.l3_itf_code, sm.l3_itf_code) AS l3_itf_code,
    if(so.l3_erp_weight != 0, so.l3_erp_weight, sm.l3_erp_weight) AS l3_erp_weight,
    if(so.l3_erp_volume != 0, so.l3_erp_volume, sm.l3_erp_volume) AS l3_erp_volume,
    if(so.l3_erp_length != 0, so.l3_erp_length, sm.l3_erp_length) AS l3_erp_length,
    if(so.l3_erp_width != 0, so.l3_erp_width, sm.l3_erp_width) AS l3_erp_width,
    if(so.l3_erp_height != 0, so.l3_erp_height, sm.l3_erp_height) AS l3_erp_height,
    if(so.l3_text_tag1 != '', so.l3_text_tag1, sm.l3_text_tag1) AS l3_text_tag1,
    if(so.l3_text_tag2 != '', so.l3_text_tag2, sm.l3_text_tag2) AS l3_text_tag2,
    if(so.l3_image != '', so.l3_image, sm.l3_image) AS l3_image,
    if(so.l3_num_tag1 != 0, so.l3_num_tag1, sm.l3_num_tag1) AS l3_num_tag1,
    
    -- System Fields
    if(so.active != false, so.active, sm.active) AS active,
    -- Classification fields (JSON merge: override properties overwrite master)
    JSONExtractRaw(JSONMergePatch(
        if(sm.classifications = '', '{}', sm.classifications),
        if(so.classifications = '', '{}', so.classifications)
    )) AS classifications,
    JSONExtractRaw(JSONMergePatch(
        if(sm.product_classifications = '', '{}', sm.product_classifications),
        if(so.product_classifications = '', '{}', so.product_classifications)
    )) AS product_classifications,
    -- Combined classification from materialized columns
    -- Uses JSON merge where override properties overwrite master properties
    JSONExtractRaw(JSONMergePatch(
        if(sm.combined_classification = '', '{}', sm.combined_classification),
        if(so.combined_classification = '', '{}', so.combined_classification)
    )) AS combined_classification,
    
    -- Metadata indicating if override exists
    if(so.sku_id IS NOT NULL, true, false) AS has_override,
    
    -- Latest update timestamp
    GREATEST(
        COALESCE(so.updated_at, toDateTime64('1970-01-01 00:00:00', 3)),
        COALESCE(sm.updated_at, toDateTime64('1970-01-01 00:00:00', 3))
    ) AS updated_at
FROM encarta_skus_master sm
LEFT JOIN encarta_skus_overrides so ON sm.id = so.sku_id AND so.node_id = {node_id:Int64} AND so.active = true
WHERE sm.active = true OR so.active = true;

-- Example usage of the parameterized view:
-- SELECT * FROM encarta_skus_combined(node_id = 123) WHERE sku_id = 'SKU001';
-- SELECT * FROM encarta_skus_combined(node_id = 456) WHERE category = 'Electronics';

-- Common query patterns:

-- 1. Get all active SKUs for a specific warehouse/node:
-- SELECT * FROM encarta_skus_combined(node_id = 123) WHERE active = true;

-- 2. Get SKU details with override information:
-- SELECT sku_id, code, name, has_override, updated_at 
-- FROM encarta_skus_combined(node_id = 123) 
-- WHERE has_override = true;

-- 3. Get SKUs by category for a node:
-- SELECT sku_id, code, name, category, brand, sub_brand
-- FROM encarta_skus_combined(node_id = 123)
-- WHERE category = 'Food' AND active = true;

-- 4. Get SKU dimensions and weights for a node:
-- SELECT sku_id, code, l0_weight, l0_volume, l0_length, l0_width, l0_height
-- FROM encarta_skus_combined(node_id = 123)
-- WHERE sku_id IN ('SKU001', 'SKU002', 'SKU003');