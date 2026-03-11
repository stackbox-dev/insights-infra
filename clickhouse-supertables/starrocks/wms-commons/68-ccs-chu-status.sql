CREATE TABLE wms_ccs_chu_status (
    id VARCHAR(36) NOT NULL,
    sessionCreatedAt DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    chuId VARCHAR(36) NOT NULL,
    type STRING NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    packedAt DATETIME,
    sblTaskId VARCHAR(36),
    qcParamsId VARCHAR(36),
    qcScoreUpdatedAt DATETIME,
    qcScore DOUBLE,
    qcThreshold DOUBLE,
    qcDivert BOOLEAN NOT NULL DEFAULT "false",
    qcMinWeight DOUBLE,
    qcWeight DOUBLE,
    qcMaxWeight DOUBLE,
    qcCompletedAt DATETIME,
    repackCount INT NOT NULL DEFAULT "0",
    sblZoneId VARCHAR(36),
    sblWave INT,
    sblPackedAt DATETIME,
    qcValue DOUBLE,
    xdock STRING,
    qcActualWt DOUBLE,
    qcActualWtMeasuredAt DATETIME,
    qcMandatoryDivert BOOLEAN NOT NULL DEFAULT "false",
    qcSblProd DOUBLE,
    qcPtlProd DOUBLE,
    mmTripId VARCHAR(36),
    lmTripId VARCHAR(36),
    invoiceIds JSON,
    sblShort BOOLEAN NOT NULL DEFAULT "false",
    ptlShort BOOLEAN NOT NULL DEFAULT "false"
)
ENGINE=OLAP
PRIMARY KEY(id, sessionCreatedAt)
PARTITION BY date_trunc('DAY', sessionCreatedAt)
DISTRIBUTED BY HASH(id)
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
