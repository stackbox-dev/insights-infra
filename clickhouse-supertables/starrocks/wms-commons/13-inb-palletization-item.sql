CREATE TABLE wms_inb_palletization_item (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    skuId VARCHAR(36) NOT NULL,
    batch STRING NOT NULL DEFAULT '',
    price STRING,
    uom STRING NOT NULL DEFAULT '',
    bucket STRING,
    qty INT NOT NULL,
    huId VARCHAR(36),
    huCode STRING,
    outerHUId VARCHAR(36),
    outerHUCode STRING,
    serializationItemId VARCHAR(36),
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    mappedAt DATETIME,
    mappedBy VARCHAR(36),
    reason STRING,
    stagingBinId VARCHAR(36),
    stagingBinHuId VARCHAR(36),
    asnId VARCHAR(36),
    asnNo STRING,
    initialBucket STRING,
    qtyInside INT,
    uomInside STRING,
    subReason STRING,
    deactivatedAt DATETIME
)
ENGINE=OLAP
PRIMARY KEY(id, createdAt)
PARTITION BY date_trunc('WEEK', createdAt)
DISTRIBUTED BY HASH(id) BUCKETS 2
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
