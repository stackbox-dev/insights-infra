CREATE TABLE IF NOT EXISTS wms_ob_order_progress
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    sessionId String DEFAULT '',
    orderId String DEFAULT '',
    invoiceId String DEFAULT '',
    invoiceCode String DEFAULT '',
    orderLineId String DEFAULT '',
    invoiceLineId String DEFAULT '',
    priority Int32 DEFAULT 0,
    skuId String DEFAULT '',
    uom String DEFAULT '',
    batch String DEFAULT '',
    orderQty Int32 DEFAULT 0,
    allocatedBatch String DEFAULT '',
    allocatedQty Int32 DEFAULT 0,
    qtyToReplenish Int32 DEFAULT 0,
    replenPickedQty Int32 DEFAULT 0,
    replenPickedAttrs String DEFAULT '{}',
    replenDroppedQty Int32 DEFAULT 0,
    replenDroppedAttrs String DEFAULT '{}',
    pickedBatch String DEFAULT '',
    pickedQty Int32 DEFAULT 0,
    pickedAttrs String DEFAULT '{}',
    droppedQty Int32 DEFAULT 0,
    droppedAttrs String DEFAULT '{}',
    loadedQty Int32 DEFAULT 0,
    loadedAttrs String DEFAULT '{}',
    unpickQty Int32 DEFAULT 0,
    unpickAttrs String DEFAULT '{}',
    repickQty Int32 DEFAULT 0,
    repickAttrs String DEFAULT '{}',
    deactivatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(deactivatedAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;