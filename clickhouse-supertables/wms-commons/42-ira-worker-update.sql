-- ClickHouse table for WMS IRA Worker Update
-- Dimension table for IRA Worker Update information
-- Source: samadhan_prod.wms.public.ira_worker_update

CREATE TABLE IF NOT EXISTS wms_ira_worker_update
(
    id String DEFAULT '',
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    huId String DEFAULT '',
    workerId String DEFAULT '',
    timestamp DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    mismatch String DEFAULT '',
    system String DEFAULT '{}',
    actual String DEFAULT '{}',
    whId Int64 DEFAULT 0
)
ENGINE = ReplacingMergeTree(timestamp)
ORDER BY (id)
SETTINGS index_granularity = 8192;