-- ClickHouse table for WMS IRA Session sku
-- Dimension table for IRA Session sku information
-- Source: samadhan_prod.wms.public.ira_session_sku

CREATE TABLE IF NOT EXISTS wms_ira_session_sku
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    sessionId String DEFAULT '',
    skuId String DEFAULT '',
    skuCode String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;