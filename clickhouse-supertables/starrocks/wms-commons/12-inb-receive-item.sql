CREATE TABLE wms_inb_receive_item (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    skuId VARCHAR(36) NOT NULL,
    uom STRING NOT NULL DEFAULT '',
    batch STRING NOT NULL DEFAULT '',
    price STRING,
    overallQty INT,
    qty INT NOT NULL,
    parentItemId VARCHAR(36),
    asnVehicleId VARCHAR(36),
    stagingBinId VARCHAR(36),
    stagingBinHUId VARCHAR(36),
    groupId VARCHAR(36),
    receivedAt DATETIME,
    receivedBy VARCHAR(36),
    receivedQty INT NOT NULL DEFAULT "0",
    damagedQty INT NOT NULL DEFAULT "0",
    deactivatedAt DATETIME,
    qcPercentage INT,
    huId VARCHAR(36),
    huCode STRING,
    reason STRING,
    bucket STRING,
    movedAt DATETIME,
    movedBy VARCHAR(36),
    processedAt DATETIME,
    huKind STRING,
    receivedHuKind STRING,
    totalHuWeight DOUBLE,
    receivedHuWeight DOUBLE,
    subReason STRING
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
