CREATE TABLE encarta_products (
    id STRING NOT NULL,
    createdAt DATETIME NULL,
    principal_id BIGINT NULL,
    code STRING NULL,
    name STRING NULL,
    description STRING NULL,
    sub_category_id STRING NULL,
    sub_brand_id STRING NULL,
    dangerous BOOLEAN NULL,
    spillable BOOLEAN NULL,
    frozen BOOLEAN NULL,
    vegetarian BOOLEAN NULL,
    dirty BOOLEAN NULL,
    origin_country STRING NULL,
    hsn_code STRING NULL,
    active BOOLEAN NULL,
    case_configuration INT NULL,
    min_quantity INT NULL,
    max_quantity INT NULL,
    order_lot INT NULL,
    taint STRING NULL,
    text_tag1 STRING NULL,
    text_tag2 STRING NULL,
    num_tag1 INT NULL,
    num_tag2 INT NULL,
    product_classifications STRING NULL,
    updated_at DATETIME NULL
)
ENGINE=OLAP
PRIMARY KEY(id)
DISTRIBUTED BY HASH(id) BUCKETS 2
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
