CREATE TABLE wms_ccs_cnode (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    code STRING NOT NULL,
    type STRING NOT NULL,
    zoneId VARCHAR(36) NOT NULL,
    attrs JSON,
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    active BOOLEAN NOT NULL DEFAULT "true",
    cmd INT NOT NULL DEFAULT "0"
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
