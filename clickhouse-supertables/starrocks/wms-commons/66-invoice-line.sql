CREATE TABLE wms_invoice_line (
    id VARCHAR(36) NOT NULL,
    sessionCreatedAt DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    invoiceId VARCHAR(36) NOT NULL,
    skuId VARCHAR(36) NOT NULL,
    qty INT NOT NULL,
    uom STRING NOT NULL DEFAULT 'L0',
    batch STRING NOT NULL DEFAULT '',
    batchAllocationType STRING NOT NULL DEFAULT 'FIXED',
    omsAllocationId VARCHAR(36),
    wave INT NULL,
    processedId VARCHAR(36),
    processedAt DATETIME,
    code STRING,
    lmTripId VARCHAR(36),
    mmTripId VARCHAR(36),
    promoCode STRING,
    ratio INT,
    promoLineType STRING,
    attrs JSON,
    deactivatedAt DATETIME,
    type STRING NOT NULL DEFAULT 'WH',
    originalQty INT NULL,
    parentLineId VARCHAR(36),
    originalSkuId VARCHAR(36)
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
