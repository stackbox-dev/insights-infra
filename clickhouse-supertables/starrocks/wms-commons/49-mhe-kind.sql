CREATE TABLE wms_mhe_kind (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    code STRING NOT NULL,
    `desc` STRING,
    carryingCapacity INT NOT NULL DEFAULT "0",
    maxBinDepth INT NOT NULL DEFAULT "0",
    maxBinLevel INT NOT NULL DEFAULT "0",
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    deactivatedAt DATETIME,
    speed INT NOT NULL DEFAULT "0"
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
