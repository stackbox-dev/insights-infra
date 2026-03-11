CREATE TABLE wms_pln_ira_cycle_step_bin (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    planId VARCHAR(36) NOT NULL,
    stepId VARCHAR(36) NOT NULL,
    areaId VARCHAR(36) NOT NULL,
    zoneId VARCHAR(36) NOT NULL,
    binId VARCHAR(36) NOT NULL,
    position INT NOT NULL DEFAULT "0",
    huCount INT NOT NULL DEFAULT "0",
    effort INT NOT NULL DEFAULT "0",
    planned BOOLEAN NOT NULL DEFAULT "false",
    excluded BOOLEAN NOT NULL DEFAULT "false",
    state STRING NOT NULL,
    recordedAt DATETIME,
    appendedAt DATETIME,
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    deactivatedAt DATETIME
)
ENGINE=OLAP
PRIMARY KEY(id, createdAt)
PARTITION BY date_trunc('DAY', createdAt)
DISTRIBUTED BY HASH(id)
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
