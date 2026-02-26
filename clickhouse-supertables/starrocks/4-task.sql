CREATE TABLE wms_tasks (
    id VARCHAR(255),
    createdAt DATETIME DEFAULT "1970-01-01 00:00:00",
    whId BIGINT DEFAULT "0",
    sessionId VARCHAR(255) DEFAULT "",
    kind VARCHAR(255) DEFAULT "",
    code VARCHAR(255) DEFAULT "",
    seq INT DEFAULT "0",
    exclusive BOOLEAN DEFAULT "0",
    state VARCHAR(255) DEFAULT "",
    attrs JSON,
    progress JSON,
    updatedAt DATETIME DEFAULT "1970-01-01 00:00:00",
    active BOOLEAN DEFAULT "1",
    allowForceComplete BOOLEAN DEFAULT "1",
    autoComplete BOOLEAN DEFAULT "0",
    wave INT DEFAULT "0",
    forceCompleteTaskId VARCHAR(255) DEFAULT "",
    forceCompleted BOOLEAN DEFAULT "0",
    subKind VARCHAR(255) DEFAULT "",
    label VARCHAR(500) DEFAULT "",
    scope VARCHAR(255) DEFAULT ""
)
ENGINE=OLAP
DUPLICATE KEY(id, createdAt)
PARTITION BY date_trunc('MONTH', createdAt)
DISTRIBUTED BY HASH(id) BUCKETS 16
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);