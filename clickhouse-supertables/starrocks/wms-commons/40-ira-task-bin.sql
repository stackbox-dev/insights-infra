CREATE TABLE wms_ira_task_bin (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    binId VARCHAR(36) NOT NULL,
    transactionId VARCHAR(36),
    state STRING NOT NULL,
    updatedBy VARCHAR(36),
    pickLockReleasedTaskIds JSON,
    attrs JSON,
    pickLockReleasedMovementDemandIds JSON,
    recordNo INT NOT NULL DEFAULT "0",
    approvalState STRING,
    recordedBy VARCHAR(36),
    recordedAt DATETIME,
    putLockReleasedTaskIds JSON,
    provisionalPickItemsReleasedKeys JSON
)
ENGINE=OLAP
PRIMARY KEY(id, createdAt)
PARTITION BY date_trunc('DAY', createdAt)
DISTRIBUTED BY HASH(id) BUCKETS 2
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
