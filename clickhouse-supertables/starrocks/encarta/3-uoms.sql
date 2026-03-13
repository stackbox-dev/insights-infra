CREATE TABLE encarta_uoms (
    id STRING NOT NULL,
    createdAt DATETIME NULL,
    principal_id BIGINT NULL,
    sku_id STRING NULL,
    name STRING NULL,
    hierarchy STRING NULL,
    weight DOUBLE NULL,
    volume DOUBLE NULL,
    package_type STRING NULL,
    length DOUBLE NULL,
    width DOUBLE NULL,
    height DOUBLE NULL,
    units INT NULL,
    packing_efficiency DOUBLE NULL,
    active BOOLEAN NULL,
    itf_code STRING NULL,
    updated_at DATETIME NULL,
    erp_weight DOUBLE NULL,
    erp_volume DOUBLE NULL,
    erp_length DOUBLE NULL,
    erp_width DOUBLE NULL,
    erp_height DOUBLE NULL,
    text_tag1 STRING NULL,
    text_tag2 STRING NULL,
    image STRING NULL,
    num_tag1 DOUBLE NULL
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
