-- ClickHouse table for WMS MHE Kind
-- Dimension table for MHE Kind information
-- Source: samadhan_prod.wms.public.mhe_kind

CREATE TABLE IF NOT EXISTS wms_mhe_kind
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    code String DEFAULT '',
    desc String DEFAULT '',
    carryingCapacity Int32 DEFAULT 0,
    maxBinDepth Int32 DEFAULT 0,
    maxBinLevel Int32 DEFAULT 0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    deactivatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    speed Int32 DEFAULT 0
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;