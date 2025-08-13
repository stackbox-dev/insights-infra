-- ClickHouse table for WMS Sessions  
-- Dimension table for session information
-- Source: sbx_uat.wms.public.session

CREATE TABLE IF NOT EXISTS wms_sessions
(
    whId Int64 DEFAULT 0,
    id String,
    kind String DEFAULT '',
    code String DEFAULT '',
    attrs String DEFAULT '{}',  -- JSON
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    active Bool DEFAULT false,
    state String DEFAULT '',
    progress String DEFAULT '{}',  -- JSON
    autoComplete Bool DEFAULT false,
    
    -- Indexes for common query patterns
    INDEX idx_whId whId TYPE minmax GRANULARITY 1,
    INDEX idx_code code TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_kind kind TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_active active TYPE minmax GRANULARITY 1,
    INDEX idx_state state TYPE bloom_filter(0.01) GRANULARITY 1
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id)  -- id is globally unique
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop',
         min_age_to_force_merge_seconds = 180
COMMENT 'WMS Sessions dimension table';

-- Add projection for common query pattern (whId, code)
ALTER TABLE wms_sessions ADD PROJECTION IF NOT EXISTS by_wh_code (
    SELECT * ORDER BY (whId, code)
);

-- Add projection for sessions by kind
ALTER TABLE wms_sessions ADD PROJECTION IF NOT EXISTS by_wh_kind (
    SELECT * ORDER BY (whId, kind, id)
);

-- Materialize the projections
ALTER TABLE wms_sessions MATERIALIZE PROJECTION by_wh_code;
ALTER TABLE wms_sessions MATERIALIZE PROJECTION by_wh_kind;