CREATE TABLE wms_pln_ira_cycle_plan (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    mode STRING NOT NULL,
    binSelectionMode STRING NOT NULL,
    startDate DATE,
    endDate DATE,
    startTimeInSeconds BIGINT NOT NULL DEFAULT "0",
    excludeDates JSON,
    userAccountId BIGINT NOT NULL,
    userAccountSessionId VARCHAR(36),
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00"
)
ENGINE=OLAP
PRIMARY KEY(id, createdAt)
PARTITION BY date_trunc('MONTH', createdAt)
DISTRIBUTED BY HASH(id) BUCKETS 2
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
