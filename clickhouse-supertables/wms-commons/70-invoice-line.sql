CREATE TABLE IF NOT EXISTS wms_invoice_line
(
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    whId Int64 DEFAULT 0,
    sessionId String DEFAULT '',
    id String,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    invoiceId String DEFAULT '',
    skuId String DEFAULT '',
    qty Int32 DEFAULT 0,
    uom String DEFAULT 'L0',
    batch String DEFAULT '',
    batchAllocationType String DEFAULT 'FIXED',
    omsAllocationId String DEFAULT '00000000-0000-0000-0000-000000000000',
    wave Int32 DEFAULT 0,
    processedId String DEFAULT '',
    processedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    code String DEFAULT '',
    lmTripId String DEFAULT '',
    mmTripId String DEFAULT '',
    promoCode String DEFAULT '',
    ratio Int32 DEFAULT 0,
    promoLineType String DEFAULT '',
    attrs String DEFAULT '{}',
    deactivatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    type String DEFAULT 'WH',
    originalQty Int32 DEFAULT 0,
    parentLineId String DEFAULT '',
    originalSkuId String DEFAULT ''
)
ENGINE = ReplacingMergeTree(createdAt)
PARTITION BY toYYYYMM(sessionCreatedAt)
ORDER BY (id, sessionCreatedAt)
SETTINGS index_granularity = 8192;
