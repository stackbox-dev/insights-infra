CREATE TABLE wms_storage_area (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    code STRING NOT NULL,
    description STRING,
    type STRING NOT NULL,
    active BOOLEAN NOT NULL DEFAULT "true",
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    rollingDays INT NOT NULL DEFAULT "0"
)
ENGINE=OLAP
PRIMARY KEY(id, createdAt)
DISTRIBUTED BY HASH(id)
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
