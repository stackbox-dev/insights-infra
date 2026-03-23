CREATE TABLE wms_ira_bin_items (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    binId VARCHAR(36) NOT NULL,
    skuId VARCHAR(36) NOT NULL,
    uom STRING NOT NULL DEFAULT '',
    systemQty INT NOT NULL DEFAULT "0",
    systemDamagedQty INT NOT NULL DEFAULT "0",
    physicalQty INT NOT NULL DEFAULT "0",
    physicalDamagedQty INT NOT NULL DEFAULT "0",
    finalQty INT NOT NULL DEFAULT "0",
    finalDamagedQty INT NOT NULL DEFAULT "0",
    issue STRING,
    state STRING NOT NULL,
    scannedAt DATETIME,
    scannedBy VARCHAR(36),
    approvedAt DATETIME,
    approvedBy VARCHAR(36),
    batch STRING NOT NULL DEFAULT '',
    processedAt DATETIME,
    sourceHUId VARCHAR(36),
    sourceHUCode STRING,
    transactionId VARCHAR(36),
    binStorageHUType STRING,
    deactivatedAt DATETIME,
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    updatedBy VARCHAR(36),
    huSameBinBeforeIRA STRING,
    recordNo INT NOT NULL DEFAULT "1",
    hlrStatus STRING,
    outerHUId VARCHAR(36),
    outerHuSameBinBeforeIRA BOOLEAN NOT NULL DEFAULT "false"
)
ENGINE=OLAP
PRIMARY KEY(id, createdAt)
PARTITION BY date_trunc('MONTH', createdAt)
DISTRIBUTED BY HASH(id) BUCKETS 2
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
