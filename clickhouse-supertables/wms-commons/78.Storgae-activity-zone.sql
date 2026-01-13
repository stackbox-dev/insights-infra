-- ClickHouse table for Storage Activity Zone
-- Dimension table for storage activity zone information
-- Source: public.storage_activity_zone

CREATE TABLE IF NOT EXISTS wms_storage_activity_zone
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '',
    code String DEFAULT '',
    description String DEFAULT '',
    zoneIds String DEFAULT '{}',  -- JSON
    active Bool DEFAULT true,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192