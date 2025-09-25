-- ClickHouse table for WMS Outbound CHU
-- Dimension table for Outbound CHU information
-- Source: samadhan_prod.wms.public.ob_chu

CREATE TABLE IF NOT EXISTS wms_ob_chu
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '', 
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sessionId String DEFAULT '',
    chuId String DEFAULT '',
    chuKindId String DEFAULT '',
    status String DEFAULT '',
    lmTripId String DEFAULT '',
    mmTripId String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    chuKind String DEFAULT '',
    type String DEFAULT ''
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;
