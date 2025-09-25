-- ClickHouse table for WMS Outbound QC CHU
-- Dimension table for Outbound QC CHU information
-- Source: samadhan_prod.wms.public.ob_qc_chu

CREATE TABLE IF NOT EXISTS wms_ob_qc_chu
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '', 
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    chuId String DEFAULT '',
    chuKindId String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    shortage Bool DEFAULT false,
    completedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    completedBy String DEFAULT '',
    breakbulkShortChu Bool DEFAULT false,
    forceCompletedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    repackingWave Int32 DEFAULT 0,
    breakbulkShortType String DEFAULT '',
    forceCompletedBy Int64 DEFAULT 0,
    scannedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    zoneId String DEFAULT ''
)
ENGINE = ReplacingMergeTree(sessionCreatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;