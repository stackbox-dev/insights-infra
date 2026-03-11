CREATE TABLE wms_pln_ira_cycle_step (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    planId VARCHAR(36) NOT NULL,
    date DATE,
    plannedStartTimestamp DATETIME,
    state STRING NOT NULL,
    plannedHuCount INT,
    startTimestamp DATETIME,
    endTimestamp DATETIME,
    iraSessionId VARCHAR(36),
    iraSessionCreatedBy BIGINT,
    plannedBinCount INT,
    unplannedBinCount INT,
    coveredPlannedBinCount INT,
    coveredUnplannedBinCount INT,
    spilledPlannedBinCount INT,
    spilledUnplannedBinCount INT,
    skippedAt DATETIME,
    skippedByUserId BIGINT,
    skippedByUserSessionId VARCHAR(36),
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00"
)
ENGINE=OLAP
PRIMARY KEY(id, createdAt)
DISTRIBUTED BY HASH(id)
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
