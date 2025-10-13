-- ClickHouse table for WMS MHE
-- Dimension table for MHE information
-- Source: samadhan_prod.wms.public.mhe

CREATE TABLE IF NOT EXISTS wms_mhe
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    code String DEFAULT '',
    kindId String DEFAULT '',
    kindCode String DEFAULT '',
    active bool DEFAULT false,
    assignedWorkerId String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;
