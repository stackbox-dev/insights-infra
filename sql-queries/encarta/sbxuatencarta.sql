CREATE TABLE IF NOT EXISTS sbx_uat_encarta.uoms 
(
    "id" UUID,
    "principal_id" Int64,
    "sku_id" UUID,
    "name" String DEFAULT 0,
    "hierarchy" String,
    "weight" Float64,
    "volume" Float64,
    "package_type" String DEFAULT 0,
    "length" Float64 DEFAULT 0,
    "width" Float64 DEFAULT 0,
    "height" Float64 DEFAULT 0,
    "units" Int32,
    "packing_efficiency" Float64 DEFAULT 0,
    "active" Bool,
    "itf_code" String DEFAULT 0,
    "created_at" DateTime64(3, 'UTC'),
    "updated_at" DateTime64(3, 'UTC'),
    "erp_weight" Float64 DEFAULT 0,
    "erp_volume" Float64 DEFAULT 0,
    "erp_length" Float64 DEFAULT 0,
    "erp_width" Float64 DEFAULT 0,
    "erp_height" Float64 DEFAULT 0,
    "text_tag1" String DEFAULT 0,
    "text_tag2" String DEFAULT 0,
    "image" String DEFAULT 0,
    "num_tag1" Float64 DEFAULT 0
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (id);


CREATE TABLE IF NOT EXISTS sbx_uat_encarta.skus 
(
    "id" UUID,
    "principal_id" Int64,
    "code" String,
    "name" String,
    "description" String DEFAULT 0,
    "short_description" String DEFAULT 0,
    "product_id" UUID,
    "ingredients" String DEFAULT 0,
    "shelf_life" Int32 DEFAULT 0,
    "fulfillment_type" String,
    "active_from" DateTime64(3, 'UTC') DEFAULT 0,
    "active_till" DateTime64(3, 'UTC') DEFAULT 0,
    "active" Bool,
    "identifier1" String DEFAULT 0,
    "identifier2" String DEFAULT 0,
    "invoice_life" Int32 DEFAULT 0,
    "avg_l0_per_put" Int32 DEFAULT 0,
    "inventory_type" String DEFAULT 0,
    "tag1" String DEFAULT 0,
    "tag2" String DEFAULT 0,
    "tag3" String DEFAULT 0,
    "tag4" String DEFAULT 0,
    "tag5" String DEFAULT 0,
    "tag6" String DEFAULT 0,
    "tag7" String DEFAULT 0,
    "tag8" String DEFAULT 0,
    "tag9" String DEFAULT 0,
    "tag10" String DEFAULT 0,
    "created_at" DateTime64(3, 'UTC'),
    "updated_at" DateTime64(3, 'UTC'),
    "layers" Int32 DEFAULT 0,
    "cases_per_layer" Int32 DEFAULT 0,
    "handling_unit_type" String DEFAULT 0
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (id);

CREATE TABLE IF NOT EXISTS sbx_uat_encarta.products 
(
    "id" UUID,
    "principal_id" Int64,
    "code" String,
    "name" String DEFAULT 0,
    "description" String DEFAULT 0,
    "sub_category_id" UUID,
    "sub_brand_id" UUID,
    "dangerous" Nullable(Bool),
    "spillable" Nullable(Bool),
    "frozen" Nullable(Bool),
    "vegetarian" Nullable(Bool),
    "dirty" Nullable(Bool),
    "origin_country" String DEFAULT 0,
    "active" Nullable(Bool),
    "case_configuration" Int32 DEFAULT 0,
    "min_quantity" Int32 DEFAULT 0,
    "max_quantity" Int32 DEFAULT 0,
    "order_lot" Int32 DEFAULT 0,
    "created_at" DateTime64(3, 'UTC') DEFAULT 0,
    "updated_at" DateTime64(3, 'UTC') DEFAULT 0,
    "taint" String DEFAULT 0,
    "text_tag1" String DEFAULT 0,
    "text_tag2" String DEFAULT 0,
    "num_tag1" Int32 DEFAULT 0,
    "num_tag2" Int32 DEFAULT 0
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (id);

CREATE TABLE IF NOT EXISTS sbx_uat_encarta.sub_categories 
(
    "id" UUID,
    "principal_id" Int64,
    "category_id" UUID,
    "code" String,
    "name" String DEFAULT 0,
    "description" String DEFAULT 0,
    "active" Nullable(Bool),
    "created_at" DateTime64(3, 'UTC') DEFAULT 0,
    "updated_at" DateTime64(3, 'UTC') DEFAULT 0
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (id);

CREATE TABLE IF NOT EXISTS sbx_uat_encarta.categories 
(
    "id" UUID,
    "principal_id" Int64,
    "category_group_id" UUID,
    "code" String,
    "name" String DEFAULT 0,
    "description" String DEFAULT 0,
    "active" Nullable(Bool),
    "created_at" DateTime64(3, 'UTC') DEFAULT 0,
    "updated_at" DateTime64(3, 'UTC') DEFAULT 0
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (id);

CREATE TABLE IF NOT EXISTS sbx_uat_encarta.classifications 
(
    "id" UUID,
    "principal_id" Int64,
    "sku_id" UUID,
    "type" String,
    "value" String DEFAULT 0,
    "created_at" DateTime64(3, 'UTC') DEFAULT 0,
    "updated_at" DateTime64(3, 'UTC') DEFAULT 0
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (id);

CREATE TABLE IF NOT EXISTS sbx_uat_encarta.node_overrides 
(
    "id" UUID,
    "principal_id" Int64,
    "sku_id" UUID,
    "node_id" Int64,
    "sku_short_description" String DEFAULT 0,
    "active" Nullable(Bool),
    "sku_description" String DEFAULT 0,
    "active_from" DateTime64(3, 'UTC') DEFAULT 0,
    "active_till" DateTime64(3, 'UTC') DEFAULT 0,
    "fulfillment_type" String DEFAULT 0,
    "avg_l0_per_put" Int32 DEFAULT 0,
    "created_at" DateTime64(3, 'UTC') DEFAULT 0,
    "updated_at" DateTime64(3, 'UTC') DEFAULT 0,
    "l3_units" Int32 DEFAULT 0,
    "l2_units" Int32 DEFAULT 0,
    "layers" Int32 DEFAULT 0,
    "cases_per_layer" Int32 DEFAULT 0,
    "handling_unit_type" String DEFAULT 0
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (id);

CREATE TABLE IF NOT EXISTS sbx_uat_encarta.node_override_classifications
(
    "id" UUID,
    "principal_id" Int64,
    "node_override_id" UUID,
    "type" String,
    "value" String DEFAULT 0,
    "created_at" DateTime64(3, 'UTC') DEFAULT 0,
    "updated_at" DateTime64(3, 'UTC') DEFAULT 0
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (id);