-- ClickHouse table for WMS Exception Bin
-- Dimension table for Exception Bin information
-- Source: samadhan_prod.wms.public.exception_bin

CREATE TABLE IF NOT EXISTS wms_exception_bin
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '',
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    correlationId String DEFAULT '',
    skuId String DEFAULT '',
    batch String DEFAULT '',
    uom String DEFAULT '',
    bucket String DEFAULT '',
    binId String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    createdBy String DEFAULT '',
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    iraSessionId String DEFAULT '',
    deletedForIRAAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;