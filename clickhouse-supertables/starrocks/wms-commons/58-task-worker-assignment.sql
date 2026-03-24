CREATE TABLE wms_task_worker_assignment (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    workerId VARCHAR(36) NOT NULL,
    assignedAt DATETIME NULL DEFAULT "1970-01-01 00:00:00",
    attrs JSON,
    mheId VARCHAR(36),
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
