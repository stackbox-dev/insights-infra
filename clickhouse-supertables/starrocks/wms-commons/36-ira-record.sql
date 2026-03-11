CREATE TABLE wms_ira_record (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    binId VARCHAR(36) NOT NULL,
    binStorageHUType STRING,
    sourceHUId VARCHAR(36),
    sourceHUCode STRING,
    skuId VARCHAR(36) NOT NULL,
    uom STRING NOT NULL DEFAULT '',
    batch STRING NOT NULL DEFAULT '',
    qty INT NOT NULL,
    damagedQty INT NOT NULL DEFAULT "0",
    createdBy VARCHAR(36),
    recordNo INT NOT NULL DEFAULT "0"
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
