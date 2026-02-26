-- ClickHouse table for WMS Outbound GIN
-- Dimension table for WMS Outbound GIN information
-- Source: samadhan_prod.wms.public.ob_gin

CREATE TABLE IF NOT EXISTS wms_ob_gin
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sessionId String DEFAULT '',
    invoiceId String DEFAULT '',
    invoiceCode String DEFAULT '',
    tripCode String DEFAULT '',
    tripId String DEFAULT '',
    status String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    submittedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    loadCompletedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;