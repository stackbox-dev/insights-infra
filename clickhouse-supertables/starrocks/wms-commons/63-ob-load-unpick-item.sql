CREATE TABLE wms_ob_load_unpick_item (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    loadItemId VARCHAR(36) NOT NULL,
    skuId VARCHAR(36) NOT NULL,
    batch STRING NOT NULL DEFAULT '',
    uom STRING NOT NULL DEFAULT '',
    bucket STRING,
    reason STRING,
    qty INT NOT NULL,
    mappedHUId VARCHAR(36),
    mappedHUCode STRING,
    mappedHUKind STRING,
    mappedAt DATETIME,
    mappedBy VARCHAR(36),
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    innerHUId VARCHAR(36),
    innerHUCode STRING,
    huId VARCHAR(36),
    quantBucket STRING NOT NULL DEFAULT 'Good',
    promoCode STRING,
    promoLineType STRING,
    unpickProcessedAt DATETIME,
    orderProgressProcessedAt DATETIME
)
ENGINE=OLAP
PRIMARY KEY(id, createdAt)
PARTITION BY date_trunc('DAY', createdAt)
DISTRIBUTED BY HASH(id) BUCKETS 16
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
