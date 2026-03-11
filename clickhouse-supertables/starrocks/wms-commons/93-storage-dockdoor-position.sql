CREATE TABLE wms_storage_dockdoor_position (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    dockdoorId VARCHAR(36) NOT NULL,
    x DOUBLE,
    y DOUBLE,
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    active BOOLEAN NOT NULL DEFAULT "true"
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
