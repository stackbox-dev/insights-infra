-- ClickHouse table for Encarta SKUs Overrides
-- Optimized data types with non-nullable defaults
-- Matches Flink sink table: sbx_uat.encarta.public.skus_overrides

CREATE TABLE IF NOT EXISTS encarta_skus_overrides
(
    -- Core Identifiers (Composite Primary Key)
    sku_id String,  -- SKU ID reference
    principal_id Int64 DEFAULT 0,
    node_id Int64 DEFAULT 0,  -- Node/warehouse identifier
    
    -- Product Hierarchy (Overrides)
    category String DEFAULT '',
    product String DEFAULT '',
    product_id String DEFAULT '',
    category_group String DEFAULT '',
    sub_brand String DEFAULT '',
    brand String DEFAULT '',
    
    -- SKU Basic Information (Overrides)
    code String DEFAULT '',
    name String DEFAULT '',
    short_description String DEFAULT '',
    description String DEFAULT '',
    fulfillment_type String DEFAULT '',
    avg_l0_per_put Int32 DEFAULT 0,
    inventory_type String DEFAULT '',
    shelf_life Int32 DEFAULT 0,
    
    -- SKU Identifiers (Overrides)
    identifier1 String DEFAULT '',
    identifier2 String DEFAULT '',
    
    -- SKU Tags (Overrides)
    tag1 String DEFAULT '',
    tag2 String DEFAULT '',
    tag3 String DEFAULT '',
    tag4 String DEFAULT '',
    tag5 String DEFAULT '',
    tag6 String DEFAULT '',
    tag7 String DEFAULT '',
    tag8 String DEFAULT '',
    tag9 String DEFAULT '',
    tag10 String DEFAULT '',
    
    -- Packaging Configuration (Overrides)
    handling_unit_type String DEFAULT '',
    cases_per_layer Int32 DEFAULT 0,
    layers Int32 DEFAULT 0,
    
    -- Activity Period (Overrides)
    active_from DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    active_till DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    
    -- Unit of Measure Hierarchy (Overrides)
    l0_units Int32 DEFAULT 0,
    l1_units Int32 DEFAULT 0,
    l2_units Int32 DEFAULT 0,
    l3_units Int32 DEFAULT 0,
    
    -- L0 (Base Unit) Specifications (Overrides)
    l0_name String DEFAULT '',
    l0_weight Float64 DEFAULT 0,
    l0_volume Float64 DEFAULT 0,
    l0_package_type String DEFAULT '',
    l0_length Float64 DEFAULT 0,
    l0_width Float64 DEFAULT 0,
    l0_height Float64 DEFAULT 0,
    l0_packing_efficiency Float64 DEFAULT 0,
    l0_itf_code String DEFAULT '',
    l0_erp_weight Float64 DEFAULT 0,
    l0_erp_volume Float64 DEFAULT 0,
    l0_erp_length Float64 DEFAULT 0,
    l0_erp_width Float64 DEFAULT 0,
    l0_erp_height Float64 DEFAULT 0,
    l0_text_tag1 String DEFAULT '',
    l0_text_tag2 String DEFAULT '',
    l0_image String DEFAULT '',
    l0_num_tag1 Float64 DEFAULT 0,
    
    -- L1 Unit Specifications (Overrides)
    l1_name String DEFAULT '',
    l1_weight Float64 DEFAULT 0,
    l1_volume Float64 DEFAULT 0,
    l1_package_type String DEFAULT '',
    l1_length Float64 DEFAULT 0,
    l1_width Float64 DEFAULT 0,
    l1_height Float64 DEFAULT 0,
    l1_packing_efficiency Float64 DEFAULT 0,
    l1_itf_code String DEFAULT '',
    l1_erp_weight Float64 DEFAULT 0,
    l1_erp_volume Float64 DEFAULT 0,
    l1_erp_length Float64 DEFAULT 0,
    l1_erp_width Float64 DEFAULT 0,
    l1_erp_height Float64 DEFAULT 0,
    l1_text_tag1 String DEFAULT '',
    l1_text_tag2 String DEFAULT '',
    l1_image String DEFAULT '',
    l1_num_tag1 Float64 DEFAULT 0,
    
    -- L2 Unit Specifications (Overrides)
    l2_name String DEFAULT '',
    l2_weight Float64 DEFAULT 0,
    l2_volume Float64 DEFAULT 0,
    l2_package_type String DEFAULT '',
    l2_length Float64 DEFAULT 0,
    l2_width Float64 DEFAULT 0,
    l2_height Float64 DEFAULT 0,
    l2_packing_efficiency Float64 DEFAULT 0,
    l2_itf_code String DEFAULT '',
    l2_erp_weight Float64 DEFAULT 0,
    l2_erp_volume Float64 DEFAULT 0,
    l2_erp_length Float64 DEFAULT 0,
    l2_erp_width Float64 DEFAULT 0,
    l2_erp_height Float64 DEFAULT 0,
    l2_text_tag1 String DEFAULT '',
    l2_text_tag2 String DEFAULT '',
    l2_image String DEFAULT '',
    l2_num_tag1 Float64 DEFAULT 0,
    
    -- L3 Unit Specifications (Overrides)
    l3_name String DEFAULT '',
    l3_weight Float64 DEFAULT 0,
    l3_volume Float64 DEFAULT 0,
    l3_package_type String DEFAULT '',
    l3_length Float64 DEFAULT 0,
    l3_width Float64 DEFAULT 0,
    l3_height Float64 DEFAULT 0,
    l3_packing_efficiency Float64 DEFAULT 0,
    l3_itf_code String DEFAULT '',
    l3_erp_weight Float64 DEFAULT 0,
    l3_erp_volume Float64 DEFAULT 0,
    l3_erp_length Float64 DEFAULT 0,
    l3_erp_width Float64 DEFAULT 0,
    l3_erp_height Float64 DEFAULT 0,
    l3_text_tag1 String DEFAULT '',
    l3_text_tag2 String DEFAULT '',
    l3_image String DEFAULT '',
    l3_num_tag1 Float64 DEFAULT 0,
    
    -- System Fields
    active Bool DEFAULT false,
    classifications String DEFAULT '{}',  -- JSON stored as String
    product_classifications String DEFAULT '{}',  -- JSON stored as String
    -- Materialized column that merges classifications (prioritized) with product_classifications
    -- Handles both array format [{"type": "ABC", "value": "C"}] and object format {"ABC": "C"}
    combined_classification String DEFAULT 
        JSONMergePatch(
            -- Base: product_classifications (converted if array)
            CASE 
                WHEN JSONType(product_classifications) = 'Array' THEN
                    arrayFold(
                        (acc, x) -> JSONMergePatch(acc, toJSONString(map(JSONExtractString(x, 'type'), JSONExtractString(x, 'value')))),
                        JSONExtractArrayRaw(product_classifications),
                        '{}'
                    )
                ELSE product_classifications
            END,
            -- Override: classifications (converted if array)
            CASE 
                WHEN JSONType(classifications) = 'Array' THEN
                    arrayFold(
                        (acc, x) -> JSONMergePatch(acc, toJSONString(map(JSONExtractString(x, 'type'), JSONExtractString(x, 'value')))),
                        JSONExtractArrayRaw(classifications),
                        '{}'
                    )
                ELSE classifications
            END
        ),
    -- Individual source table timestamps
    node_override_created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    node_override_updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sku_master_created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sku_master_updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    product_node_override_created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    product_node_override_updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    -- Aggregated timestamps (MIN for created, MAX for updated)
    created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    -- Indexes for faster lookups in WMS enrichment
    INDEX idx_sku_id sku_id TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_node_id node_id TYPE minmax GRANULARITY 1,
    INDEX idx_principal_id principal_id TYPE minmax GRANULARITY 1,
    INDEX idx_code code TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_sku_node (sku_id, node_id) TYPE minmax GRANULARITY 1,
    INDEX idx_category category TYPE bloom_filter(0.01) GRANULARITY 4,
    INDEX idx_brand brand TYPE bloom_filter(0.01) GRANULARITY 4,
    INDEX idx_active active TYPE minmax GRANULARITY 1
) 
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (node_id, code)
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop',
         min_age_to_force_merge_seconds = 180
COMMENT 'Encarta SKUs node-specific overrides for warehouse-specific customizations';

-- Projection for SKU + Node lookups (most common in enrichment)
ALTER TABLE encarta_skus_overrides ADD PROJECTION proj_by_sku_node (
    SELECT 
        sku_id,
        node_id,
        principal_id,
        category,
        product,
        product_id,
        category_group,
        sub_brand,
        brand,
        code,
        name,
        short_description,
        description,
        fulfillment_type,
        inventory_type,
        shelf_life,
        handling_unit_type,
        l0_units,
        l1_units,
        l2_units,
        l3_units,
        l0_weight,
        l0_volume,
        active,
        updated_at
    ORDER BY (sku_id, node_id)
);

-- Projection for node-specific lookups
ALTER TABLE encarta_skus_overrides ADD PROJECTION proj_by_node (
    SELECT 
        node_id,
        sku_id,
        code,
        name,
        category,
        brand,
        active
    ORDER BY (node_id, sku_id)
);