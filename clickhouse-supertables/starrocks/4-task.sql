CREATE TABLE wms_tasks (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    kind STRING NOT NULL,
    code STRING NOT NULL,
    seq INT NOT NULL,
    exclusive BOOLEAN NOT NULL,
    state STRING NOT NULL,
    attrs JSON,
    progress JSON,
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    active BOOLEAN DEFAULT "true",
    allowForceComplete BOOLEAN DEFAULT "true",
    autoComplete BOOLEAN DEFAULT "false",
    wave INT,
    forceCompleteTaskId VARCHAR(36),
    forceCompleted BOOLEAN NOT NULL DEFAULT "false",
    subKind STRING NOT NULL DEFAULT '',
    label STRING NOT NULL DEFAULT '',
    scope STRING NOT NULL DEFAULT ''
)
ENGINE=OLAP
PRIMARY KEY(id, createdAt)
PARTITION BY date_trunc('DAY', createdAt)
DISTRIBUTED BY HASH(id) BUCKETS 16
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);