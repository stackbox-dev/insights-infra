CREATE TABLE wms_inb_unload_item (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    huId VARCHAR(36) NOT NULL,
    huCode STRING NOT NULL,
    qty INT NOT NULL,
    stagingBinId VARCHAR(36),
    receivedAt DATETIME,
    receivedBy VARCHAR(36),
    movedAt DATETIME,
    movedBy VARCHAR(36),
    processedAt DATETIME,
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00"
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
