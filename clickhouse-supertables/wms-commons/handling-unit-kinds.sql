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
SETTINGS index_granularity = 8192
COMMENT 'WMS Handling Unit Kinds dimension table';

-- Add projection for common query pattern (whId, code)
ALTER TABLE wms_handling_unit_kinds ADD PROJECTION IF NOT EXISTS by_wh_code (
    SELECT * ORDER BY (whId, code)
);

-- Add projection for active kinds by usage type
ALTER TABLE wms_handling_unit_kinds ADD PROJECTION IF NOT EXISTS by_usage_active (
    SELECT * WHERE active = true ORDER BY (whId, usageType, id)
);

-- Materialize the projections
ALTER TABLE wms_handling_unit_kinds MATERIALIZE PROJECTION by_wh_code;
ALTER TABLE wms_handling_unit_kinds MATERIALIZE PROJECTION by_usage_active;