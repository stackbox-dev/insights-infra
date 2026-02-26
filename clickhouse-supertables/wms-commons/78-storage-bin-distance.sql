-- ClickHouse table for Storage Bin Distance
-- Dimension table for storage bin distance and position information
-- Source: public.storage_bin_distance

CREATE TABLE IF NOT EXISTS wms_storage_bin_distance
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '',
    aisle String DEFAULT '',
    binId String DEFAULT '',
    binCode String DEFAULT '',
    xPosition Float64 DEFAULT 0.0,
    yPosition Float64 DEFAULT 0.0,
    zPosition Float64 DEFAULT 0.0,
    aisleStart Float64 DEFAULT 0.0,
    aisleEnd Float64 DEFAULT 0.0,
    aisleDirection String DEFAULT '',
    active Bool DEFAULT true,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    type String DEFAULT 'BIN'
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192