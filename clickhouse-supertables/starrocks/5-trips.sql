CREATE TABLE wms_trips (
    id VARCHAR(255),
    sessionCreatedAt DATETIME DEFAULT "1970-01-01 00:00:00",
    whId BIGINT DEFAULT "0",
    sessionId VARCHAR(255) DEFAULT "",
    createdAt DATETIME DEFAULT "1970-01-01 00:00:00",
    bbId VARCHAR(255) DEFAULT "",
    code VARCHAR(255) DEFAULT "",
    type VARCHAR(255) DEFAULT "",
    priority INT DEFAULT "0",
    dockdoorId VARCHAR(255) DEFAULT "",
    dockdoorCode VARCHAR(255) DEFAULT "",
    vehicleId VARCHAR(255) DEFAULT "",
    vehicleNo VARCHAR(255) DEFAULT "",
    vehicleType VARCHAR(255) DEFAULT "",
    deliveryDate DATE,
    stagingBinId VARCHAR(255) DEFAULT ""
)
ENGINE=OLAP
DUPLICATE KEY(id, sessionCreatedAt)
PARTITION BY date_trunc('MONTH', createdAt)
DISTRIBUTED BY HASH(id) BUCKETS 16
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);