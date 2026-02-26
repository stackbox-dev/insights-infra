-- ClickHouse table for Storage Dockdoor Position
-- Source: public.storage_dockdoor_position

CREATE TABLE IF NOT EXISTS wms_storage_dockdoor_position
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    dockdoorId String DEFAULT '',
    x Float64 DEFAULT 0.0,
    y Float64 DEFAULT 0.0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    active Bool DEFAULT true,
    PRIMARY KEY (id)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;