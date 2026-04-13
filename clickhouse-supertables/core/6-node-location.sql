-- ClickHouse table for Node Location
-- Source: public.node_location

CREATE TABLE IF NOT EXISTS backbone_node_location
(
    id String DEFAULT '',
    nodeId Int64 DEFAULT 0,
    type String DEFAULT '',
    latitude Float64 DEFAULT 0.0,
    longitude Float64 DEFAULT 0.0,
    geoAccuracy Float64 DEFAULT 0.0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    active Bool DEFAULT true
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (nodeId, id)
SETTINGS index_granularity = 8192;
