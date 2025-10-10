-- ClickHouse table for WMS IRA Discrepancies Config
-- Dimension table for IRA Discrepancies Config information
-- Source: samadhan_prod.wms.public.ira_discrepancies_config

CREATE TABLE IF NOT EXISTS wms_ira_discrepancies_config
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    category String DEFAULT '',
    class String DEFAULT '',
    attribute String DEFAULT '',
    threshold String DEFAULT '',
    unit String DEFAULT 'NONE',
    priority Int32 DEFAULT 0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    active bool DEFAULT false,
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;