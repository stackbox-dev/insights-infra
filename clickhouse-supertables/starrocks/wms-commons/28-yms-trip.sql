CREATE TABLE wms_yms_trip (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    tripCode STRING NOT NULL,
    retailerCodes JSON,
    dispatchDate DATETIME,
    transporter STRING,
    vehicleType STRING,
    vehicleNo STRING,
    tripVolume DOUBLE,
    tripTonnage DOUBLE,
    tripDistance DOUBLE,
    earliestExitTime DATETIME,
    latestExitTime DATETIME,
    loadingTime INT,
    caseCount INT,
    deactivatedAt DATETIME,
    deactivatedBy BIGINT,
    lrNumber STRING,
    trailerNo STRING,
    truckLoadType STRING,
    retailerChannel STRING,
    retailerName STRING,
    orderType STRING,
    priority STRING,
    sessionKind STRING,
    dockdoorId VARCHAR(36),
    dockdoorCode STRING
)
ENGINE=OLAP
PRIMARY KEY(id, createdAt)
PARTITION BY date_trunc('DAY', createdAt)
DISTRIBUTED BY HASH(id)
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
