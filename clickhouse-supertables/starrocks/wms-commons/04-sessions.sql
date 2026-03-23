CREATE TABLE wms_sessions (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    kind STRING NOT NULL,
    code STRING NOT NULL,
    attrs JSON,
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    active BOOLEAN NOT NULL DEFAULT "false",
    state STRING NOT NULL,
    progress JSON,
    autoComplete BOOLEAN NOT NULL DEFAULT "false"
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
