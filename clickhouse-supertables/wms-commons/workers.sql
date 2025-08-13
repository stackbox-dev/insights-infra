-- ClickHouse table for WMS Workers
-- Dimension table for worker information
-- Source: sbx_uat.wms.public.worker

CREATE TABLE IF NOT EXISTS wms_workers
(
    whId Int64 DEFAULT 0,
    id String,
    code String DEFAULT '',
    name String DEFAULT '',
    phone String DEFAULT '',
    attrs String DEFAULT '{}',  -- JSON
    images String DEFAULT '[]',  -- JSON array
    active Bool DEFAULT true,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    supervisor Bool DEFAULT false,
    quantIdentifiers String DEFAULT '{}',  -- JSON
    mheKindIds String DEFAULT '[]',  -- JSON array
    eligibleZones String DEFAULT '[]',  -- JSON array
    
    -- Indexes for common query patterns
    INDEX idx_whId whId TYPE minmax GRANULARITY 1,
    INDEX idx_code code TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_active active TYPE minmax GRANULARITY 1
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id)  -- id is globally unique
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop',
         min_age_to_force_merge_seconds = 180
COMMENT 'WMS Workers dimension table';

-- Projection optimized for JOIN on id (primary enrichment pattern)
-- Already optimal since ORDER BY (id) is the primary key

-- Projection for warehouse + code lookups
ALTER TABLE wms_workers ADD PROJECTION proj_by_wh_code (
    SELECT 
        whId,
        code,
        id,
        name,
        active,
        supervisor
    ORDER BY (whId, code)
);

-- Projection for warehouse-based worker lookups
ALTER TABLE wms_workers ADD PROJECTION proj_by_wh_id (
    SELECT 
        whId,
        id,
        code,
        name,
        active
    ORDER BY (whId, id)
);