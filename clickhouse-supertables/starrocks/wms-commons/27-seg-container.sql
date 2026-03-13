CREATE TABLE wms_seg_container (
    id VARCHAR(36) NOT NULL,
    sessionCreatedAt DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    groupId VARCHAR(36) NOT NULL,
    type STRING NOT NULL,
    containerId VARCHAR(36) NOT NULL,
    containerCode STRING NOT NULL,
    active BOOLEAN NOT NULL DEFAULT "false",
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    workerId VARCHAR(36),
    usedCapacity INT,
    maxCapacity INT,
    usedVolume DOUBLE,
    maxVolume DOUBLE,
    itemVolume DOUBLE
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
