-- ClickHouse table for Encarta SKUs Master
-- Optimized data types with non-nullable defaults
-- Matches Flink sink table: sbx_uat.encarta.public.skus_master

CREATE TABLE IF NOT EXISTS encarta_skus_master
(
    -- Core Identifiers (Primary Key)
    id String,  -- SKU ID, primary key
    principal_id Int64 DEFAULT 0,
    
    -- Product Hierarchy
    category String DEFAULT '',
    product String DEFAULT '',
    product_id String DEFAULT '',
    category_group String DEFAULT '',
    sub_brand String DEFAULT '',
    brand String DEFAULT '',
    
    -- SKU Basic Information
    code String DEFAULT '',
    name String DEFAULT '',
    short_description String DEFAULT '',
    description String DEFAULT '',
    fulfillment_type String DEFAULT '',
    avg_l0_per_put Int32 DEFAULT 0,
    inventory_type String DEFAULT '',
    shelf_life Int32 DEFAULT 0,
    
    -- SKU Identifiers
    identifier1 String DEFAULT '',
    identifier2 String DEFAULT '',
    
    -- SKU Tags
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
    
    -- Packaging Configuration
    handling_unit_type String DEFAULT '',
    cases_per_layer Int32 DEFAULT 0,
    layers Int32 DEFAULT 0,
    
    -- Activity Period
    active_from DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    active_till DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    
    -- Unit of Measure Hierarchy
    l0_units Int32 DEFAULT 0,
    l1_units Int32 DEFAULT 0,
    l2_units Int32 DEFAULT 0,
    l3_units Int32 DEFAULT 0,
    
    -- L0 (Base Unit) Specifications
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
    
    -- L1 Unit Specifications
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
    
    -- L2 Unit Specifications
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
    
    -- L3 Unit Specifications
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
    classifications String DEFAULT '{}',  -- JSON, default empty object
    product_classifications String DEFAULT '{}',  -- JSON, default empty object
    is_snapshot Bool DEFAULT false,
    created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    event_time DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
) 
ENGINE = ReplacingMergeTree(event_time)
ORDER BY (principal_id, code)
SETTINGS index_granularity = 8192
COMMENT 'Encarta SKUs master data with complete product hierarchy and UOM specifications';