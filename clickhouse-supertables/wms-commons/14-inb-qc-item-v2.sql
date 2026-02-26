-- ClickHouse table for WMS Inbound Quality Check Item
-- Dimension table for Inbound Quality Check Item information
-- Source: samadhan_prod.wms.public.inb_qc_item_v2

CREATE TABLE IF NOT EXISTS wms_inb_qc_item_v2
(
    id String,
    whId Int64 DEFAULT 0,
    sessionId String,
    taskId String,
    skuId String,
    uom String DEFAULT '',
    batch String DEFAULT '',
    bucket String DEFAULT '',
    price String DEFAULT '',
    qty Int32 DEFAULT 0,
    receivedQty Int32 DEFAULT 0,
    sampleSize Int32 DEFAULT 0,
    inspectionLevel String DEFAULT '',
    acceptableIssueSize Int32 DEFAULT 0,
    actualSkuId String DEFAULT '',
    actualUom String DEFAULT '',
    actualBatch String DEFAULT '',
    actualPrice String DEFAULT '',
    actualBucket String DEFAULT '',
    actualQty Int32 DEFAULT 0,
    actualQtyInside Int32 DEFAULT 0,
    parentItemId String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    createdBy String DEFAULT '',
    deactivatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    deactivatedBy String DEFAULT '',
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    movedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    movedBy String DEFAULT '',
    movedQty Int32 DEFAULT 0,
    processedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    uomInside String DEFAULT '',
    reason String DEFAULT '',
    subReason String DEFAULT '',
    batchOverridden String DEFAULT ''
)
ENGINE = ReplacingMergeTree(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;