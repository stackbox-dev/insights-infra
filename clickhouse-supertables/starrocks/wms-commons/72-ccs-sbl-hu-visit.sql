CREATE TABLE wms_ccs_sbl_hu_visit (
    id VARCHAR(36) NOT NULL,
    sessionCreatedAt DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    wave INT NOT NULL DEFAULT "0",
    taskId VARCHAR(36) NOT NULL,
    zoneId VARCHAR(36) NOT NULL,
    huId VARCHAR(36) NOT NULL,
    assignedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    predictedToArriveAt DATETIME,
    divertedAt DATETIME,
    packedAt DATETIME,
    predictedWorkTime INT
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
