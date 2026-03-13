CREATE TABLE wms_ira_bin_items_scanned_hu (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    iraItemId VARCHAR(36) NOT NULL,
    huId VARCHAR(36) NOT NULL,
    huCode STRING NOT NULL,
    bucket STRING,
    deactivatedAt DATETIME,
    scannedAt DATETIME,
    scannedBy VARCHAR(36),
    sameBinBeforeIRA BOOLEAN NOT NULL DEFAULT "false",
    systemBucket STRING
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
