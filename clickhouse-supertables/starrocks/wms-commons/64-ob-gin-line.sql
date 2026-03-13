CREATE TABLE wms_ob_gin_line (
    id VARCHAR(36) NOT NULL,
    sessionCreatedAt DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    ginId VARCHAR(36) NOT NULL,
    invoiceId VARCHAR(36) NOT NULL,
    invoiceCode STRING NOT NULL,
    tripCode STRING NOT NULL,
    tripId VARCHAR(36) NOT NULL,
    invoiceLineId VARCHAR(36) NOT NULL,
    skuId VARCHAR(36) NOT NULL,
    batch STRING NOT NULL DEFAULT '',
    uom STRING NOT NULL DEFAULT '',
    loadedQty INT NOT NULL DEFAULT "0",
    approvedBy BIGINT,
    approvedAt DATETIME,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    pickedQty INT NOT NULL DEFAULT "0",
    shortageQty INT NOT NULL DEFAULT "0",
    huId VARCHAR(36),
    huCode STRING,
    extraFields JSON,
    loadCompletedAt DATETIME,
    initialLoadedQty INT NOT NULL DEFAULT "0"
)
ENGINE=OLAP
PRIMARY KEY(id, sessionCreatedAt)
PARTITION BY date_trunc('DAY', sessionCreatedAt)
DISTRIBUTED BY HASH(id) BUCKETS 2
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
