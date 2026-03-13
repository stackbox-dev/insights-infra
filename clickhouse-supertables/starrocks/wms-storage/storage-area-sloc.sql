CREATE TABLE wms_storage_area_sloc (
    id STRING NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NULL,
    areaCode STRING NULL,
    quality STRING NULL,
    sloc STRING NULL,
    slocDescription STRING NULL,
    clientQuality STRING NULL,
    inventoryVisible BOOLEAN NULL,
    erpToWMS BOOLEAN NULL,
    iloc STRING NULL,
    deactivatedAt DATETIME NULL,
    updatedAt DATETIME NULL
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
