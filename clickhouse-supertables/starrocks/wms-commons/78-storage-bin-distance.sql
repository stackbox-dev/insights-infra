CREATE TABLE wms_storage_bin_distance (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    aisle STRING NOT NULL,
    binId VARCHAR(36) NOT NULL,
    binCode STRING NOT NULL,
    xPosition DOUBLE,
    yPosition DOUBLE,
    zPosition DOUBLE,
    aisleStart DOUBLE,
    aisleEnd DOUBLE,
    aisleDirection STRING,
    active BOOLEAN NOT NULL DEFAULT "true",
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    type STRING NOT NULL DEFAULT 'BIN'
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
