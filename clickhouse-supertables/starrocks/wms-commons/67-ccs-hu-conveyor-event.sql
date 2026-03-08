CREATE TABLE wms_ccs_hu_conveyor_event (
    id VARCHAR(36) NOT NULL,
    sessionCreatedAt DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    huId VARCHAR(36) NOT NULL,
    innerHuId VARCHAR(36),
    nodeId VARCHAR(36) NOT NULL,
    timestamp DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    event STRING NOT NULL DEFAULT 'SCANNED',
    plannedDestNodeId VARCHAR(36),
    purpose STRING,
    hwTimestamp DATETIME
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
