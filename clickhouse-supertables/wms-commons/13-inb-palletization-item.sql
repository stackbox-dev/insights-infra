-- ClickHouse table for WMS Inbound Palletization Item
-- Dimension table for Inbound Palletization Item information
-- Source: samadhan_prod.wms.public.inb_palletization_item

CREATE TABLE IF NOT EXISTS wms_inb_palletization_item
(
    id String,
    whId Int64 DEFAULT 0,
    sessionId String,
    taskId String,
    skuId String,
    batch String DEFAULT '',
    price String DEFAULT '',
    uom String DEFAULT '',
    bucket String DEFAULT '',
    qty Int32 DEFAULT 0,
    huId String DEFAULT '',
    huCode String DEFAULT '',
    outerHUId String DEFAULT '',
    outerHUCode String DEFAULT '',
    serializationItemId String,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    mappedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    mappedBy String DEFAULT '',
    reason String DEFAULT '',
    stagingBinId String DEFAULT '',
    stagingBinHuId String DEFAULT '',
    asnId String DEFAULT '',
    asnNo String DEFAULT '',
    initialBucket String DEFAULT '',
    qtyInside Int32 DEFAULT 0,
    uomInside String DEFAULT '',
    subReason String DEFAULT '',
    deactivatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;