-- ClickHouse table for WMS Inbound Receive Item
-- Dimension table for INB line item information
-- Source: samadhan_prod.wms.public.inb_receive_item

CREATE TABLE IF NOT EXISTS wms_inb_receive_item
(
    whId Int64 DEFAULT 0,
    sessionId String,
    taskId String,
    id String,
    skuId String,
    uom String,
    batch String,
    price String,
    overallQty Int32,
    qty Int32,
    parentItemId String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    asnVehicleId String DEFAULT '',
    stagingBinId String DEFAULT '',
    stagingBinHUId String DEFAULT '',
    groupId String DEFAULT '',
    receivedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    receivedBy String DEFAULT '',
    receivedQty Int32 DEFAULT 0,
    damagedQty Int32 DEFAULT 0,
    deactivatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    qcPercentage Int32 DEFAULT 0,
    huId String DEFAULT '',
    huCode String DEFAULT '',
    reason String DEFAULT '',
    bucket String DEFAULT '',
    movedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    movedBy String DEFAULT '',
    processedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    huKind String DEFAULT '',
    receivedHuKind String DEFAULT '',
    totalHuWeight Float64 DEFAULT 0,
    receivedHuWeight Float64 DEFAULT 0,
    subReason String DEFAULT '',
) 
ENGINE = ReplacingMergeTree(receivedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;