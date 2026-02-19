
-- ClickHouse table for Storage Position
-- Source: public.storage_position

CREATE TABLE IF NOT EXISTS wms_storage_position
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    storageId String DEFAULT '',
    x1 Float64 DEFAULT 0.0,
    x2 Float64 DEFAULT 0.0,
    y1 Float64 DEFAULT 0.0,
    y2 Float64 DEFAULT 0.0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    active Bool DEFAULT true,
    PRIMARY KEY (id)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;