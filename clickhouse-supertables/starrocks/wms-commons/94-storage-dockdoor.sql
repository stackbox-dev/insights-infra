CREATE TABLE wms_storage_dockdoor (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    code STRING NOT NULL,
    description STRING,
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    maxQueue BIGINT NOT NULL DEFAULT "0",
    allowInbound BOOLEAN NOT NULL DEFAULT "false",
    allowOutbound BOOLEAN NOT NULL DEFAULT "false",
    allowReturns BOOLEAN NOT NULL DEFAULT "false",
    incompatibleVehicleTypes JSON,
    status STRING,
    incompatibleLoadTypes JSON
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
