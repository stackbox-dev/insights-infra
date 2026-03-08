CREATE TABLE wms_ob_qc_chu (
    id VARCHAR(36) NOT NULL,
    sessionCreatedAt DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    chuId VARCHAR(36) NOT NULL,
    chuKindId VARCHAR(36),
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    shortage BOOLEAN NOT NULL DEFAULT "false",
    completedAt DATETIME,
    completedBy VARCHAR(36),
    breakbulkShortChu BOOLEAN NOT NULL DEFAULT "false",
    forceCompletedAt DATETIME,
    repackingWave INT,
    breakbulkShortType STRING,
    forceCompletedBy BIGINT,
    scannedAt DATETIME,
    zoneId VARCHAR(36)
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
