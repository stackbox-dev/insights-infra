-- ClickHouse table for CCS CNode
-- Dimension table for conveyor system nodes
-- Source: samadhan_prod.wms.public.ccs_cnode

CREATE TABLE IF NOT EXISTS wms_ccs_cnode
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '',
    code String DEFAULT '',
    type String DEFAULT '',
    zoneId String DEFAULT '',
    attrs String DEFAULT '{}',  -- JSON
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    active bool DEFAULT true,
    cmd Int32 DEFAULT 0
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192
COMMENT 'CCS CNode dimension table';