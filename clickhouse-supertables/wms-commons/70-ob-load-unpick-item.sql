CREATE TABLE IF NOT EXISTS wms_ob_load_unpick_item
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '',
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    loadItemId String DEFAULT '',
    skuId String DEFAULT '',
    batch String DEFAULT '',
    uom String DEFAULT '',
    bucket String DEFAULT '',
    reason String DEFAULT '',
    qty Int32 DEFAULT 0,
    mappedHUId String DEFAULT '',
    mappedHUCode String DEFAULT '',
    mappedHUKind String DEFAULT '',
    mappedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    mappedBy String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    innerHUId String DEFAULT '',
    innerHUCode String DEFAULT '',
    huId String DEFAULT '',
    quantBucket String DEFAULT 'Good',
    promoCode String DEFAULT '',
    promoLineType String DEFAULT '',
    unpickProcessedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    orderProgressProcessedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;