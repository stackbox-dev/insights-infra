CREATE TABLE wms_ob_order_lineitem (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    orderId VARCHAR(36) NOT NULL,
    skuId VARCHAR(36) NOT NULL,
    uom STRING NOT NULL DEFAULT 'L0',
    batch STRING NOT NULL DEFAULT '',
    qty INT NOT NULL,
    extraFields JSON,
    value INT NOT NULL,
    huId VARCHAR(36),
    huCode STRING,
    huWeight DOUBLE,
    deliveryOrder STRING,
    customerOrderQty INT,
    deliveryOrderQty INT,
    processFlag STRING,
    promoCode STRING,
    promoLineType STRING,
    ratio INT,
    salesAllocationLossReceivedAt DATETIME,
    deactivatedAt DATETIME,
    lineCode STRING,
    deactivationReason STRING,
    iloc STRING NOT NULL DEFAULT '',
    invoicingQty INT
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