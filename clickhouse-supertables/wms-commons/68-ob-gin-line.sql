CREATE TABLE IF NOT EXISTS wms_ob_gin_line
(
    whId Int64 DEFAULT 0,
    id String,
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00',3),
    sessionId String DEFAULT '',
    ginId String DEFAULT '',
    invoiceId String DEFAULT '',
    invoiceCode String DEFAULT '',
    tripCode String DEFAULT '',
    tripId String DEFAULT '',
    invoiceLineId String DEFAULT '',
    skuId String DEFAULT '',
    batch String DEFAULT '',
    uom String DEFAULT '',
    loadedQty Int32 DEFAULT 0,
    approvedBy Int64 DEFAULT 0,
    approvedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00',3),
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00',3),
    pickedQty Int32 DEFAULT 0,
    shortageQty Int32 DEFAULT 0,
    huId String DEFAULT '',
    huCode String DEFAULT '',
    extraFields String DEFAULT '{}',
    loadCompletedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00',3),
    initialLoadedQty Int32 DEFAULT 0
)
ENGINE = ReplacingMergeTree(createdAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;