-- ClickHouse table for WMS Exception Manual Assignment
-- Dimension table for Exception Manual Assignment information
-- Source: samadhan_prod.wms.public.exception_manual_assignment

CREATE TABLE IF NOT EXISTS wms_exception_manual_assignment
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '',
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    correlationId String DEFAULT '',
    originalBinId String DEFAULT '',
    reAssignedBinId String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    createdBy String DEFAULT '',
    skuId String DEFAULT '',
    batch String DEFAULT '',
    uom String DEFAULT '',
    bucket String DEFAULT '',
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    iraSessionId String DEFAULT '',
    deletedForIRAAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    reason String DEFAULT '',
    kind String DEFAULT '',
    level String DEFAULT '',
    mode String DEFAULT '',
    correlation String DEFAULT '{}'
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;