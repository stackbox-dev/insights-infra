-- ClickHouse table for WMS Invoice Lines
-- Dimension table for Invoice line information
-- Source: samadhan_prod.wms.public.invoice_line

CREATE TABLE IF NOT EXISTS wms_invoice_line
(
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    whId Int64 DEFAULT 0, 
    sessionId String,
    id String,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    invoiceId String,
    skuId String,
    qty Int32 DEFAULT 0,
    uom String DEFAULT '',
    batch String DEFAULT '',
    batchAllocationType String DEFAULT '',
    omsAllocationId String DEFAULT '',
    wave Int32 DEFAULT 0,
    processedId String DEFAULT '',
    processedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    originalSkuId String DEFAULT '',
    code String DEFAULT '',
    lmTripId String DEFAULT '',
    mmTripId String DEFAULT '',
    promoCode String DEFAULT '',
    ratio Int32 DEFAULT 0,
    promoLineType String DEFAULT '',
    attrs String DEFAULT '{}', -- JSON
    deactivatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    type String DEFAULT '',
    originalQty Int32 DEFAULT 0,
    parentLineId String DEFAULT 0
)
ENGINE = ReplacingMergeTree(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;
