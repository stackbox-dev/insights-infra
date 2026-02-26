CREATE TABLE wms_ob_load_item (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    tripId VARCHAR(36) NOT NULL,
    skuId VARCHAR(36) NOT NULL,
    skuClass STRING NOT NULL,
    uom STRING NOT NULL,
    qty INT NOT NULL,
    seq BIGINT NOT NULL,
    loadedQty INT,
    loadedBy VARCHAR(36),
    loadedAt DATETIME,
    invoiceId VARCHAR(36),
    skuCategory STRING,
    originalSkuId VARCHAR(36) NOT NULL,
    batch STRING NOT NULL DEFAULT '',
    huId VARCHAR(36),
    huCode STRING,
    mmTripId VARCHAR(36),
    innerHUId VARCHAR(36),
    innerHUCode STRING,
    innerHUKind STRING,
    binId VARCHAR(36),
    binHUId VARCHAR(36),
    binCode STRING,
    parentItemId VARCHAR(36),
    classificationType STRING,
    originalQty INT,
    originalUOM STRING,
    repicked BOOLEAN DEFAULT "false",
    invoiceCode STRING,
    retailerId STRING,
    retailerCode STRING,
    retailerName STRING,
    retailerCity STRING,
    orderProgressProcessedAt DATETIME,
    iloc STRING NOT NULL DEFAULT '',
    salesOrderCode STRING
)
ENGINE=OLAP
DUPLICATE KEY(id, createdAt)
PARTITION BY date_trunc('DAY', createdAt)
DISTRIBUTED BY HASH(id) BUCKETS 16
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);