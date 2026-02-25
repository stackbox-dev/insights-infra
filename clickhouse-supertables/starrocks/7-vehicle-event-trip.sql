CREATE TABLE wms_vehicle_event_trip (
    id VARCHAR(255),
    createdAt DATETIME DEFAULT "1970-01-01 00:00:00",
    whId BIGINT DEFAULT "0",
    vehicleEventId VARCHAR(255) DEFAULT "",
    sessionId VARCHAR(255) DEFAULT "",
    tripId VARCHAR(255) DEFAULT "",
    tripCode VARCHAR(255) DEFAULT "",
    active BOOLEAN DEFAULT "1",
    updatedAt DATETIME DEFAULT "1970-01-01 00:00:00"
)
ENGINE=OLAP
DUPLICATE KEY(id, createdAt)
PARTITION BY date_trunc('MONTH', createdAt)
DISTRIBUTED BY HASH(id) BUCKETS 16
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);