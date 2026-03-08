CREATE TABLE wms_sbl_bin_chu (
    id VARCHAR(36) NOT NULL,
    sessionCreatedAt DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    zoneId VARCHAR(36) NOT NULL,
    binId VARCHAR(36) NOT NULL,
    chuId VARCHAR(36) NOT NULL,
    chuKindId VARCHAR(36),
    chuKind STRING,
    assignedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    assignedBy VARCHAR(36),
    closedAt DATETIME,
    closedBy VARCHAR(36),
    deactivatedAt DATETIME,
    hybrid BOOLEAN NOT NULL DEFAULT "false",
    recoId VARCHAR(36),
    maxVolume DOUBLE,
    maxWeight DOUBLE,
    ptlDemandGroupId VARCHAR(36),
    repacking BOOLEAN NOT NULL DEFAULT "false",
    shortage BOOLEAN NOT NULL DEFAULT "false",
    canBeRemovedAt DATETIME
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
