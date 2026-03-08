CREATE TABLE wms_vehicle_parking (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    vehicleEventId VARCHAR(36) NOT NULL,
    parkingSlotId VARCHAR(36) NOT NULL,
    parkingSlotCode STRING NOT NULL,
    parkingZoneId VARCHAR(36),
    parkingZoneCode STRING,
    parkingZoneType STRING,
    parkedInAt DATETIME,
    parkedOutAt DATETIME,
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00"
)
ENGINE=OLAP
PRIMARY KEY(id, createdAt)
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
