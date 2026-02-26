-- ClickHouse table for WMS Inbound Serialization Item
-- Dimension table for Inbound Serialization Item information
-- Source: samadhan_prod.wms.public.inb_serialization_item

CREATE TABLE IF NOT EXISTS wms_inb_serialization_item
(
    id String,
    whId Int64 DEFAULT 0,
    sessionId String,
    taskId String,
    skuId String DEFAULT '',
    batch String DEFAULT '',
    uom String DEFAULT '',
    qty Int32 DEFAULT 0,
    huId String DEFAULT '',
    huCode String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    serializedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    serializedBy String DEFAULT '',
    bucket String DEFAULT '',
    stagingBinId String DEFAULT '',
    stagingBinHuId String DEFAULT '',
    qtyInside Int32 DEFAULT 0,
    printLabel String DEFAULT '',
    preparedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    preparedBy String DEFAULT '',
    uomInside String DEFAULT '',
    reason String DEFAULT '',
    subReason String DEFAULT '',
    reasonUpdatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    reasonUpdatedBy String DEFAULT '',
    mode String DEFAULT '',
    rejected Bool DEFAULT False,
    deactivatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(serializedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;