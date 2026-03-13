CREATE TABLE wms_seg_group (
    id VARCHAR(36) NOT NULL,
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    taskSubKind STRING,
    sortingStrategy STRING,
    `key` STRING NOT NULL,
    binId VARCHAR(36),
    zoneId VARCHAR(36),
    expectedCount INT
)
ENGINE=OLAP
PRIMARY KEY(id)
DISTRIBUTED BY HASH(id) BUCKETS 2
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
