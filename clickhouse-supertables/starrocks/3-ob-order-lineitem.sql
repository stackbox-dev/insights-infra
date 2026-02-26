CREATE TABLE wms_ob_order_lineitem (
    id VARCHAR(255),
    createdAt DATETIME DEFAULT "1970-01-01 00:00:00",
    whId BIGINT DEFAULT "0",
    orderId VARCHAR(255) DEFAULT "",
    skuId VARCHAR(255) DEFAULT "",
    uom VARCHAR(100) DEFAULT "L0",
    batch VARCHAR(255) DEFAULT "",
    qty INT DEFAULT "0",
    extraFields JSON,
    value INT DEFAULT "0",
    huId VARCHAR(255) DEFAULT "",
    huCode VARCHAR(255) DEFAULT "",
    huWeight DOUBLE DEFAULT "0",
    deliveryOrder VARCHAR(255) DEFAULT "",
    customerOrderQty INT DEFAULT "0",
    deliveryOrderQty INT DEFAULT "0",
    processFlag VARCHAR(255) DEFAULT "",
    promoCode VARCHAR(255) DEFAULT "",
    promoLineType VARCHAR(255) DEFAULT "",
    ratio INT DEFAULT "0",
    salesAllocationLossReceivedAt DATETIME,
    deactivatedAt DATETIME,
    lineCode VARCHAR(255) DEFAULT "",
    deactivationReason VARCHAR(500) DEFAULT "",
    iloc VARCHAR(255) DEFAULT "",
    invoicingQty INT DEFAULT "0"
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