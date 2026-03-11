CREATE TABLE wms_ira_manual_update (
    id VARCHAR(36) NOT NULL,
    timestamp DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    huId VARCHAR(36) NOT NULL,
    accountId BIGINT NOT NULL,
    `system` JSON,
    actual JSON
)
ENGINE=OLAP
PRIMARY KEY(id, timestamp)
PARTITION BY date_trunc('DAY', timestamp)
DISTRIBUTED BY HASH(id)
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
