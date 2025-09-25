-- ClickHouse table for WMS Wave OLG Invoice Line
-- Dimension table for Wave OLG Invoice Line information
-- Source: samadhan_prod.wms.public.wave_olg_invoice_line

CREATE TABLE IF NOT EXISTS wms_wave_olg_invoice_line
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '', 
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sessionId String DEFAULT '',
    wavePreviewId String DEFAULT '',
    waveOlgBinId String DEFAULT '',
    invoiceId String DEFAULT '',
    lineId String DEFAULT '',
    skuId String DEFAULT '',
    qty Int32 DEFAULT 0,
    crateId String DEFAULT '',
    crateTypeId String DEFAULT '',
    fulfillmentType String DEFAULT '',
    lineFulfillmentType String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    lmTripId String DEFAULT '',
    mmTripId String DEFAULT '' 
)
ENGINE = ReplacingMergeTree(sessionCreatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;