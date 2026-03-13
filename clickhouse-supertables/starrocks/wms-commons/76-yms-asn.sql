CREATE TABLE wms_yms_asn (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    asnNo STRING NOT NULL,
    dispatchDate DATETIME,
    deliveryDate DATETIME,
    vehicleNo STRING NOT NULL,
    vehicleType STRING,
    transporter STRING,
    plantCode STRING,
    tripVolume DOUBLE,
    tripTonnage DOUBLE,
    unloadingTime INT,
    caseCount INT,
    deactivatedAt DATETIME,
    deactivatedBy BIGINT,
    groupId VARCHAR(36),
    poNos VARCHAR(65535),
    deliveryNos VARCHAR(65535),
    lrNumber STRING,
    trailerNo STRING,
    tripCode STRING,
    truckLoadType STRING,
    iloc STRING NOT NULL DEFAULT ''
)
ENGINE=OLAP
PRIMARY KEY(id, createdAt)
PARTITION BY date_trunc('DAY', createdAt)
DISTRIBUTED BY HASH(id) BUCKETS 2
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
