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
    COALESCE(so.code, sm.code, '') AS code,
    COALESCE(so.name, sm.name, '') AS name,
    COALESCE(so.short_description, sm.short_description, '') AS short_description,
    COALESCE(so.description, sm.description, '') AS description,
    COALESCE(so.fulfillment_type, sm.fulfillment_type, '') AS fulfillment_type,
    COALESCE(so.avg_l0_per_put, sm.avg_l0_per_put, 0) AS avg_l0_per_put,
    COALESCE(so.inventory_type, sm.inventory_type, '') AS inventory_type,
    COALESCE(so.shelf_life, sm.shelf_life, 0) AS shelf_life,
    
    -- SKU Identifiers
    COALESCE(so.identifier1, sm.identifier1, '') AS identifier1,
    COALESCE(so.identifier2, sm.identifier2, '') AS identifier2,
    
    -- SKU Tags
    COALESCE(so.tag1, sm.tag1, '') AS tag1,
    COALESCE(so.tag2, sm.tag2, '') AS tag2,
    COALESCE(so.tag3, sm.tag3, '') AS tag3,
    COALESCE(so.tag4, sm.tag4, '') AS tag4,
    COALESCE(so.tag5, sm.tag5, '') AS tag5,
    COALESCE(so.tag6, sm.tag6, '') AS tag6,
    COALESCE(so.tag7, sm.tag7, '') AS tag7,
    COALESCE(so.tag8, sm.tag8, '') AS tag8,
    COALESCE(so.tag9, sm.tag9, '') AS tag9,
    COALESCE(so.tag10, sm.tag10, '') AS tag10,
    
    -- Packaging Configuration
    COALESCE(so.handling_unit_type, sm.handling_unit_type, '') AS handling_unit_type,
    COALESCE(so.cases_per_layer, sm.cases_per_layer, 0) AS cases_per_layer,
    COALESCE(so.layers, sm.layers, 0) AS layers,
    
    -- Activity Period
    COALESCE(so.active_from, sm.active_from, toDateTime64('1970-01-01 00:00:00', 3)) AS active_from,
    COALESCE(so.active_till, sm.active_till, toDateTime64('1970-01-01 00:00:00', 3)) AS active_till,
    
    -- Unit of Measure Hierarchy
    COALESCE(so.l0_units, sm.l0_units, 0) AS l0_units,
    COALESCE(so.l1_units, sm.l1_units, 0) AS l1_units,
    COALESCE(so.l2_units, sm.l2_units, 0) AS l2_units,
    COALESCE(so.l3_units, sm.l3_units, 0) AS l3_units,
    
    -- L0 (Base Unit) Specifications
    COALESCE(so.l0_name, sm.l0_name, '') AS l0_name,
    COALESCE(so.l0_weight, sm.l0_weight, 0) AS l0_weight,
    COALESCE(so.l0_volume, sm.l0_volume, 0) AS l0_volume,
    COALESCE(so.l0_package_type, sm.l0_package_type, '') AS l0_package_type,
    COALESCE(so.l0_length, sm.l0_length, 0) AS l0_length,
    COALESCE(so.l0_width, sm.l0_width, 0) AS l0_width,
    COALESCE(so.l0_height, sm.l0_height, 0) AS l0_height,
    COALESCE(so.l0_packing_efficiency, sm.l0_packing_efficiency, 0) AS l0_packing_efficiency,
    COALESCE(so.l0_itf_code, sm.l0_itf_code, '') AS l0_itf_code,
    COALESCE(so.l0_erp_weight, sm.l0_erp_weight, 0) AS l0_erp_weight,
    COALESCE(so.l0_erp_volume, sm.l0_erp_volume, 0) AS l0_erp_volume,
    COALESCE(so.l0_erp_length, sm.l0_erp_length, 0) AS l0_erp_length,
    COALESCE(so.l0_erp_width, sm.l0_erp_width, 0) AS l0_erp_width,
    COALESCE(so.l0_erp_height, sm.l0_erp_height, 0) AS l0_erp_height,
    COALESCE(so.l0_text_tag1, sm.l0_text_tag1, '') AS l0_text_tag1,
    COALESCE(so.l0_text_tag2, sm.l0_text_tag2, '') AS l0_text_tag2,
    COALESCE(so.l0_image, sm.l0_image, '') AS l0_image,
    COALESCE(so.l0_num_tag1, sm.l0_num_tag1, 0) AS l0_num_tag1,
    
    -- L1 Unit Specifications
    COALESCE(so.l1_name, sm.l1_name, '') AS l1_name,
    COALESCE(so.l1_weight, sm.l1_weight, 0) AS l1_weight,
    COALESCE(so.l1_volume, sm.l1_volume, 0) AS l1_volume,
    COALESCE(so.l1_package_type, sm.l1_package_type, '') AS l1_package_type,
    COALESCE(so.l1_length, sm.l1_length, 0) AS l1_length,
    COALESCE(so.l1_width, sm.l1_width, 0) AS l1_width,
    COALESCE(so.l1_height, sm.l1_height, 0) AS l1_height,
    COALESCE(so.l1_packing_efficiency, sm.l1_packing_efficiency, 0) AS l1_packing_efficiency,
    COALESCE(so.l1_itf_code, sm.l1_itf_code, '') AS l1_itf_code,
    COALESCE(so.l1_erp_weight, sm.l1_erp_weight, 0) AS l1_erp_weight,
    COALESCE(so.l1_erp_volume, sm.l1_erp_volume, 0) AS l1_erp_volume,
    COALESCE(so.l1_erp_length, sm.l1_erp_length, 0) AS l1_erp_length,
    COALESCE(so.l1_erp_width, sm.l1_erp_width, 0) AS l1_erp_width,
    COALESCE(so.l1_erp_height, sm.l1_erp_height, 0) AS l1_erp_height,
    COALESCE(so.l1_text_tag1, sm.l1_text_tag1, '') AS l1_text_tag1,
    COALESCE(so.l1_text_tag2, sm.l1_text_tag2, '') AS l1_text_tag2,
    COALESCE(so.l1_image, sm.l1_image, '') AS l1_image,
    COALESCE(so.l1_num_tag1, sm.l1_num_tag1, 0) AS l1_num_tag1,
    
    -- L2 Unit Specifications
    COALESCE(so.l2_name, sm.l2_name, '') AS l2_name,
    COALESCE(so.l2_weight, sm.l2_weight, 0) AS l2_weight,
    COALESCE(so.l2_volume, sm.l2_volume, 0) AS l2_volume,
    COALESCE(so.l2_package_type, sm.l2_package_type, '') AS l2_package_type,
    COALESCE(so.l2_length, sm.l2_length, 0) AS l2_length,
    COALESCE(so.l2_width, sm.l2_width, 0) AS l2_width,
    COALESCE(so.l2_height, sm.l2_height, 0) AS l2_height,
    COALESCE(so.l2_packing_efficiency, sm.l2_packing_efficiency, 0) AS l2_packing_efficiency,
    COALESCE(so.l2_itf_code, sm.l2_itf_code, '') AS l2_itf_code,
    COALESCE(so.l2_erp_weight, sm.l2_erp_weight, 0) AS l2_erp_weight,
    COALESCE(so.l2_erp_volume, sm.l2_erp_volume, 0) AS l2_erp_volume,
    COALESCE(so.l2_erp_length, sm.l2_erp_length, 0) AS l2_erp_length,
    COALESCE(so.l2_erp_width, sm.l2_erp_width, 0) AS l2_erp_width,
    COALESCE(so.l2_erp_height, sm.l2_erp_height, 0) AS l2_erp_height,
    COALESCE(so.l2_text_tag1, sm.l2_text_tag1, '') AS l2_text_tag1,
    COALESCE(so.l2_text_tag2, sm.l2_text_tag2, '') AS l2_text_tag2,
    COALESCE(so.l2_image, sm.l2_image, '') AS l2_image,
    COALESCE(so.l2_num_tag1, sm.l2_num_tag1, 0) AS l2_num_tag1,
    
    -- L3 Unit Specifications
    COALESCE(so.l3_name, sm.l3_name, '') AS l3_name,
    COALESCE(so.l3_weight, sm.l3_weight, 0) AS l3_weight,
    COALESCE(so.l3_volume, sm.l3_volume, 0) AS l3_volume,
    COALESCE(so.l3_package_type, sm.l3_package_type, '') AS l3_package_type,
    COALESCE(so.l3_length, sm.l3_length, 0) AS l3_length,
    COALESCE(so.l3_width, sm.l3_width, 0) AS l3_width,
    COALESCE(so.l3_height, sm.l3_height, 0) AS l3_height,
    COALESCE(so.l3_packing_efficiency, sm.l3_packing_efficiency, 0) AS l3_packing_efficiency,
    COALESCE(so.l3_itf_code, sm.l3_itf_code, '') AS l3_itf_code,
    COALESCE(so.l3_erp_weight, sm.l3_erp_weight, 0) AS l3_erp_weight,
    COALESCE(so.l3_erp_volume, sm.l3_erp_volume, 0) AS l3_erp_volume,
    COALESCE(so.l3_erp_length, sm.l3_erp_length, 0) AS l3_erp_length,
    COALESCE(so.l3_erp_width, sm.l3_erp_width, 0) AS l3_erp_width,
    COALESCE(so.l3_erp_height, sm.l3_erp_height, 0) AS l3_erp_height,
    COALESCE(so.l3_text_tag1, sm.l3_text_tag1, '') AS l3_text_tag1,
    COALESCE(so.l3_text_tag2, sm.l3_text_tag2, '') AS l3_text_tag2,
    COALESCE(so.l3_image, sm.l3_image, '') AS l3_image,
    COALESCE(so.l3_num_tag1, sm.l3_num_tag1, 0) AS l3_num_tag1,
    
    -- System Fields
    COALESCE(so.active, sm.active, false) AS active,
    -- Classification fields
    COALESCE(so.classifications, sm.classifications, '{}') AS classifications,
    COALESCE(so.product_classifications, sm.product_classifications, '{}') AS product_classifications,
    -- Combined classification from materialized columns
    -- Uses override's combined_classification if available, otherwise master's
    -- Each table's combined_classification already prioritizes classifications over product_classifications
    COALESCE(so.combined_classification, sm.combined_classification, '{}') AS combined_classification,
    
    -- Metadata indicating if override exists
    if(so.sku_id IS NOT NULL, true, false) AS has_override,
    
    -- Latest update timestamp
    GREATEST(
        COALESCE(so.updated_at, toDateTime64('1970-01-01 00:00:00', 3)),
        COALESCE(sm.updated_at, toDateTime64('1970-01-01 00:00:00', 3))
    ) AS updated_at
FROM encarta_skus_master sm
LEFT JOIN encarta_skus_overrides so ON sm.id = so.sku_id AND so.node_id = {node_id:Int64}
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