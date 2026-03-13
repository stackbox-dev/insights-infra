CREATE TABLE wms_inb_serialization_item (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    skuId VARCHAR(36) NOT NULL,
    batch STRING NOT NULL DEFAULT '',
    uom STRING NOT NULL DEFAULT '',
    qty INT NOT NULL,
    huId VARCHAR(36),
    huCode STRING,
    serializedAt DATETIME,
    serializedBy VARCHAR(36),
    bucket STRING,
    stagingBinId VARCHAR(36),
    stagingBinHuId VARCHAR(36),
    qtyInside INT,
    printLabel STRING,
    preparedAt DATETIME,
    preparedBy VARCHAR(36),
    uomInside STRING,
    reason STRING,
    subReason STRING,
    reasonUpdatedAt DATETIME,
    reasonUpdatedBy VARCHAR(36),
    mode STRING,
    rejected BOOLEAN NOT NULL DEFAULT "false",
    deactivatedAt DATETIME
)
ENGINE=OLAP
PRIMARY KEY(id, createdAt)
PARTITION BY date_trunc('DAY', createdAt)
DISTRIBUTED BY HASH(id) BUCKETS 2
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
