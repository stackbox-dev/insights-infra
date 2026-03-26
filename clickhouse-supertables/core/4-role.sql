-- ClickHouse table for Role
-- Source: public.role

CREATE TABLE IF NOT EXISTS backbone_role
(
    id String DEFAULT '',
    code String DEFAULT '',
    nodeId Int64 DEFAULT 0,
    description String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    active Bool DEFAULT true,
    name String DEFAULT ''
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;
