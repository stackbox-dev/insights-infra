-- ClickHouse table for WMS IRA Bin Items Scanned HU
-- Dimension table for IRA Bin Items Scanned Hu information
-- Source: samadhan_prod.wms.public.ira_bin_items_scanned_hu

CREATE TABLE IF NOT EXISTS wms_ira_bin_items_scanned_hu
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    iraItemId String DEFAULT '',
    huId String DEFAULT '',
    huCode String DEFAULT '',
    bucket String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    deactivatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    scannedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    scannedBy String DEFAULT '',
    sameBinBeforeIRA bool DEFAULT false,
    systemBucket String DEFAULT ''
)
ENGINE = ReplacingMergeTree(deactivatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;
