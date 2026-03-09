CREATE TABLE wms_exception_hu (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    correlationId VARCHAR(36),
    skuId VARCHAR(36) NOT NULL,
    batch STRING NOT NULL DEFAULT '',
    uom STRING NOT NULL DEFAULT '',
    binId VARCHAR(36) NOT NULL,
    huId VARCHAR(36) NOT NULL,
    systemQty INT NOT NULL DEFAULT "0",
    systemDamagedQty INT NOT NULL DEFAULT "0",
    qty INT NOT NULL,
    damagedQty INT NOT NULL DEFAULT "0",
    createdBy VARCHAR(36),
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    iraSessionId VARCHAR(36),
    deletedForIRAAt DATETIME
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
