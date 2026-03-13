CREATE TABLE backbone_node (
    id BIGINT NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    parentId BIGINT NOT NULL DEFAULT "0",
    `group` STRING NOT NULL DEFAULT '',
    code STRING NOT NULL DEFAULT '',
    name STRING NOT NULL DEFAULT '',
    type STRING NOT NULL DEFAULT '',
    data JSON,
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    active BOOLEAN NOT NULL DEFAULT "true",
    hasLocations BOOLEAN NOT NULL DEFAULT "false",
    platform STRING NULL
)
ENGINE=OLAP
PRIMARY KEY(id, createdAt)
DISTRIBUTED BY HASH(id) BUCKETS 2
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
