CREATE TABLE encarta_batches (
    id STRING NOT NULL,
    createdAt DATETIME NULL,
    principal_id BIGINT NULL,
    sku_id STRING NULL,
    code STRING NULL,
    batch_name STRING NULL,
    batch_desc STRING NULL,
    source_factory STRING NULL,
    case_config INT NULL,
    packing_date DATETIME NULL,
    expiry_date DATETIME NULL,
    active BOOLEAN NULL,
    price DOUBLE NULL,
    price_lot STRING NULL,
    identifier1 STRING NULL,
    tag1 STRING NULL,
    sku_code STRING NULL,
    updated_at DATETIME NULL
)
ENGINE=OLAP
PRIMARY KEY(id)
DISTRIBUTED BY HASH(id)
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
