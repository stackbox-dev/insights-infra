CREATE TABLE wms_handling_units (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    code STRING NOT NULL,
    kindId VARCHAR(36),
    sessionId VARCHAR(36),
    taskId VARCHAR(36),
    storageId VARCHAR(36),
    outerHuId VARCHAR(36),
    state STRING NOT NULL,
    attrs JSON,
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    lockTaskId VARCHAR(36),
    effectiveStorageId VARCHAR(36)
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
