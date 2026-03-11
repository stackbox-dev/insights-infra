CREATE TABLE backbone_user_account (
    id BIGINT NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    loginId STRING NOT NULL DEFAULT '',
    name STRING NOT NULL DEFAULT '',
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    active BOOLEAN NOT NULL DEFAULT "true",
    phone STRING NOT NULL DEFAULT '',
    email STRING NOT NULL DEFAULT '',
    apiKey STRING NOT NULL DEFAULT '',
    nodeId BIGINT NOT NULL DEFAULT "0",
    createdBy BIGINT NOT NULL DEFAULT "0",
    updatedBy BIGINT NOT NULL DEFAULT "0"
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
