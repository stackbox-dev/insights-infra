
CREATE TABLE IF NOT EXISTS wms_handling_unit_quant_event
(
    whId Int64 DEFAULT 0,
    id String,
    huEventId String DEFAULT '',
    skuId String DEFAULT '',
    uom String DEFAULT '',
    bucket String DEFAULT '',
    batch String DEFAULT '',
    price String DEFAULT '',
    inclusionStatus String DEFAULT '',
    lockedByTaskId String DEFAULT '',
    lockMode String DEFAULT '',
    qtyAdded Int32 DEFAULT 0,
    iloc String DEFAULT '',
    timestamp DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(timestamp)
PARTITION BY toYYYYMM(timestamp)
ORDER BY (id)
SETTINGS index_granularity = 8192;
