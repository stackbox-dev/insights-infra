CREATE TABLE wms_ob_order_progress (
    id VARCHAR(36) NOT NULL,
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36),
    orderId VARCHAR(36) NOT NULL,
    invoiceId VARCHAR(36),
    invoiceCode STRING,
    orderLineId VARCHAR(36),
    invoiceLineId VARCHAR(36),
    priority INT NOT NULL DEFAULT "0",
    skuId VARCHAR(36) NOT NULL,
    uom STRING NOT NULL DEFAULT '',
    batch STRING NOT NULL DEFAULT '',
    orderQty INT NOT NULL DEFAULT "0",
    allocatedBatch STRING,
    allocatedQty INT NOT NULL DEFAULT "0",
    qtyToReplenish INT NOT NULL DEFAULT "0",
    replenPickedQty INT NOT NULL DEFAULT "0",
    replenPickedAttrs JSON,
    replenDroppedQty INT NOT NULL DEFAULT "0",
    replenDroppedAttrs JSON,
    pickedBatch STRING,
    pickedQty INT NOT NULL DEFAULT "0",
    pickedAttrs JSON,
    droppedQty INT NOT NULL DEFAULT "0",
    droppedAttrs JSON,
    loadedQty INT NOT NULL DEFAULT "0",
    loadedAttrs JSON,
    unpickQty INT NOT NULL DEFAULT "0",
    unpickAttrs JSON,
    repickQty INT NOT NULL DEFAULT "0",
    repickAttrs JSON,
    deactivatedAt DATETIME
)
ENGINE=OLAP
PRIMARY KEY(id)
DISTRIBUTED BY HASH(id)
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
