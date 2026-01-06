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
    cmd Int32 DEFAULT 0,
    
    -- Indexes for common query patterns
    INDEX idx_whId whId TYPE minmax GRANULARITY 1,
    INDEX idx_code code TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_type type TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_active active TYPE minmax GRANULARITY 1
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;