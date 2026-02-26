-- ClickHouse table for Provisional GIN
-- Dimension table for provisional goods issue note information
-- Source: public.provisional_gin

CREATE TABLE IF NOT EXISTS wms_provisional_gin
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '',
    sessionId String DEFAULT '',
    orderId String DEFAULT '',
    orderCode String DEFAULT '',
    tripCode String DEFAULT '',
    status String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192