CREATE TABLE wms_handling_unit_kinds (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    code STRING NOT NULL,
    name STRING NOT NULL,
    attrs JSON,
    active BOOLEAN NOT NULL DEFAULT "true",
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    maxVolume DOUBLE NOT NULL DEFAULT "1000000",
    maxWeight DOUBLE NOT NULL DEFAULT "1000000",
    usageType STRING NOT NULL DEFAULT '',
    abbr STRING,
    length DOUBLE,
    breadth DOUBLE,
    height DOUBLE,
    weight DOUBLE
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
