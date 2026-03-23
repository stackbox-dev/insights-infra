CREATE TABLE wms_bbulk_ptl_bin_reduction (
    id VARCHAR(36) NOT NULL,
    sessionCreatedAt DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    zoneId VARCHAR(36) NOT NULL,
    groupId VARCHAR(36) NOT NULL,
    chuId VARCHAR(36) NOT NULL,
    visitId VARCHAR(36),
    chuAssignmentId VARCHAR(36),
    binAssignmentId VARCHAR(36),
    qty INT NOT NULL,
    newQty INT NOT NULL,
    reason STRING,
    reducedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    reducedBy VARCHAR(36)
)
ENGINE=OLAP
PRIMARY KEY(id, sessionCreatedAt)
PARTITION BY date_trunc('MONTH', sessionCreatedAt)
DISTRIBUTED BY HASH(id) BUCKETS 2
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
