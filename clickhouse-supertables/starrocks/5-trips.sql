CREATE TABLE wms_trips (
    id VARCHAR(36) NOT NULL,
    sessionCreatedAt DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    bbId STRING,
    code STRING NOT NULL,
    type STRING NOT NULL,
    priority INT NOT NULL,
    dockdoorId STRING,
    dockdoorCode STRING,
    vehicleId STRING,
    vehicleNo STRING,
    vehicleType STRING,
    deliveryDate DATE,
    stagingBinId STRING
)
ENGINE=OLAP
PRIMARY KEY(id, sessionCreatedAt)
PARTITION BY date_trunc('DAY', createdAt)
DISTRIBUTED BY HASH(id) BUCKETS 16
ORDER BY (id)   
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);