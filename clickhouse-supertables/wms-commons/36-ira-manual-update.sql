-- ClickHouse table for WMS IRA Manual Updates
-- Dimension table for IRA Manual Updates information
-- Source: samadhan_prod.wms.public.ira_manual_update

CREATE TABLE IF NOT EXISTS wms_ira_manual_update
(
    id String DEFAULT '',
    taskId String DEFAULT '',
    huId String DEFAULT '',
    accountId Int64 DEFAULT 0,
    timestamp DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    system String DEFAULT '',
    actual String DEFAULT '',
    whId Int64 DEFAULT 0
)
ENGINE = ReplacingMergeTree(timestamp)
ORDER BY (id)
SETTINGS index_granularity = 8192;
