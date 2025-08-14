-- ClickHouse table for WMS Handling Unit Kinds
-- Dimension table for handling unit kind/type information
-- Source: sbx_uat.wms.public.handling_unit_kind

CREATE TABLE IF NOT EXISTS wms_handling_unit_kinds
(
    whId Int64 DEFAULT 0,
    id String,
    code String DEFAULT '',
    name String DEFAULT '',
    attrs String DEFAULT '{}',  -- JSON
    active Bool DEFAULT true,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    maxVolume Float64 DEFAULT 1000000,
    maxWeight Float64 DEFAULT 1000000,
    usageType String DEFAULT '',
    abbr String DEFAULT '',
    length Float64 DEFAULT 0,
    breadth Float64 DEFAULT 0,
    height Float64 DEFAULT 0,
    weight Float64 DEFAULT 0,
    
    -- Indexes for common query patterns
    INDEX idx_whId whId TYPE minmax GRANULARITY 1,
    INDEX idx_code code TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_usageType usageType TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_active active TYPE minmax GRANULARITY 1
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id)  -- id is globally unique
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop',
         min_age_to_force_merge_seconds = 180
COMMENT 'WMS Handling Unit Kinds dimension table';

-- Projections removed to prevent stale data issues in enrichment MVs
-- Table is already optimized with ORDER BY (id) for direct JOIN performance