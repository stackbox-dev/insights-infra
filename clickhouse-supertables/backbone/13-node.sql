-- ClickHouse table for Node
-- Source: public.node

CREATE TABLE IF NOT EXISTS backbone_node
(
    id Int64 DEFAULT 0,
    parentId Int64 DEFAULT 0,
    group String DEFAULT '',
    code String DEFAULT '',
    name String DEFAULT '',
    type String DEFAULT '',
    data String DEFAULT '{}',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    active Bool DEFAULT true,
    hasLocations Bool DEFAULT false,
    platform String DEFAULT ''
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;