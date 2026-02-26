-- ClickHouse table for WMS IRA Session Summary
-- Dimension table for IRA Session Summary information
-- Source: samadhan_prod.wms.public.ira_session_summary

CREATE TABLE IF NOT EXISTS wms_ira_session_summary
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    sessionId String DEFAULT '',
    skuId String DEFAULT '',
    uom String DEFAULT '',
    batch String DEFAULT '',
    totalCount Int32 DEFAULT 0,
    hitCount Int32 DEFAULT 0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;
