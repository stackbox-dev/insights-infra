-- ClickHouse table for WMS IRA Approval
-- Dimension table for IRA Approval information
-- Source: samadhan_prod.wms.public.ira_approval

CREATE TABLE IF NOT EXISTS wms_ira_approval
(
    id String DEFAULT '',
    accountId Int64 DEFAULT 0,
    timestamp DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    approved String DEFAULT '{}',
    whId Int64 DEFAULT 0
)
ENGINE = ReplacingMergeTree(timestamp)
ORDER BY (id)
SETTINGS index_granularity = 8192;