-- ClickHouse table for WMS Outbound CHU
-- Dimension table for Outbound CHU information
-- Source: samadhan_prod.wms.public.ob_chu_line

CREATE TABLE IF NOT EXISTS wms_ob_chu_line
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '', 
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sessionId String DEFAULT '',
    obCHUId String DEFAULT '',
    chuId String DEFAULT '',
    invoiceId String DEFAULT '',
    invoiceLineId String DEFAULT '',
    skuId String DEFAULT '',
    batch String DEFAULT '',
    uom String DEFAULT '',
    qty Int32 DEFAULT 0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    inventoryHUId String DEFAULT '',
    inventoryBinId String DEFAULT '',
    packedBy String DEFAULT ''
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;