CREATE TABLE wms_seg_item (
    id VARCHAR(36) NOT NULL,
    sessionCreatedAt DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    insertionId VARCHAR(36) NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    `key` STRING NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    groupId VARCHAR(36),
    huId VARCHAR(36),
    containerId VARCHAR(36),
    assignedAt DATETIME,
    workerId VARCHAR(36),
    attrs JSON,
    volume DOUBLE
)
ENGINE=OLAP
PRIMARY KEY(id, sessionCreatedAt)
PARTITION BY date_trunc('DAY', sessionCreatedAt)
DISTRIBUTED BY HASH(id) BUCKETS 16
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
