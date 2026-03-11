CREATE TABLE wms_hht_pick_group (
    id VARCHAR(36) NOT NULL,
    sessionCreatedAt DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    sblTaskId VARCHAR(36),
    sblZoneId VARCHAR(36),
    priority INT NOT NULL,
    huId VARCHAR(36),
    binId VARCHAR(36),
    binAssignedAt DATETIME,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    mappedAt DATETIME,
    mappedBy VARCHAR(36)
)
ENGINE=OLAP
PRIMARY KEY(id, sessionCreatedAt)
PARTITION BY date_trunc('DAY', sessionCreatedAt)
DISTRIBUTED BY HASH(id)
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
