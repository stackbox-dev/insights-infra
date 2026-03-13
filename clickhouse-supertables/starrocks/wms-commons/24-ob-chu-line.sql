CREATE TABLE wms_ob_chu_line (
    id VARCHAR(36) NOT NULL,
    sessionCreatedAt DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    obCHUId VARCHAR(36) NOT NULL,
    chuId VARCHAR(36) NOT NULL,
    invoiceId VARCHAR(36) NOT NULL,
    invoiceLineId VARCHAR(36) NOT NULL,
    skuId VARCHAR(36) NOT NULL,
    batch STRING NOT NULL DEFAULT '',
    uom STRING NOT NULL DEFAULT '',
    qty INT NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    inventoryHUId VARCHAR(36),
    inventoryBinId VARCHAR(36),
    packedBy VARCHAR(36)
)
ENGINE=OLAP
PRIMARY KEY(id, sessionCreatedAt)
PARTITION BY date_trunc('DAY', sessionCreatedAt)
DISTRIBUTED BY HASH(id) BUCKETS 2
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
