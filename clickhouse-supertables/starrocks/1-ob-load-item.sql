CREATE TABLE wms_ob_load_item (
    id VARCHAR(255),
    createdAt DATETIME DEFAULT "1970-01-01 00:00:00",
    whId BIGINT DEFAULT "0",
    sessionId VARCHAR(255),
    taskId VARCHAR(255),
    tripId VARCHAR(255),
    skuId VARCHAR(255),
    skuClass VARCHAR(255) DEFAULT "",
    uom VARCHAR(100) DEFAULT "",
    qty INT DEFAULT "0",
    seq BIGINT DEFAULT "0",
    loadedQty INT DEFAULT "0",
    loadedBy VARCHAR(255) DEFAULT "",
    loadedAt DATETIME,
    invoiceId VARCHAR(255) DEFAULT "",
    skuCategory VARCHAR(255) DEFAULT "",
    originalSkuId VARCHAR(255) DEFAULT "",
    batch VARCHAR(255) DEFAULT "",
    huId VARCHAR(255) DEFAULT "",
    huCode VARCHAR(255) DEFAULT "",
    mmTripId VARCHAR(255) DEFAULT "",
    innerHUId VARCHAR(255) DEFAULT "",
    innerHUCode VARCHAR(255) DEFAULT "",
    innerHUKind VARCHAR(255) DEFAULT "",
    binId VARCHAR(255) DEFAULT "",
    binHUId VARCHAR(255) DEFAULT "",
    binCode VARCHAR(255) DEFAULT "",
    parentItemId VARCHAR(255) DEFAULT "",
    classificationType VARCHAR(255) DEFAULT "",
    originalQty INT DEFAULT "0",
    originalUOM VARCHAR(100) DEFAULT "",
    repicked BOOLEAN DEFAULT "0",
    invoiceCode VARCHAR(255) DEFAULT "",
    retailerId VARCHAR(255) DEFAULT "",
    retailerCode VARCHAR(255) DEFAULT ""
)
ENGINE=OLAP
DUPLICATE KEY(id, createdAt)
PARTITION BY date_trunc('MONTH', createdAt)
DISTRIBUTED BY HASH(id) BUCKETS 16
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);