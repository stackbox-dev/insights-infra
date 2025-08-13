-- ClickHouse table for WMS Tasks
-- Dimension table for task information  
-- Source: sbx_uat.wms.public.task

CREATE TABLE IF NOT EXISTS wms_tasks
(
    whId Int64 DEFAULT 0,
    id String,
    sessionId String DEFAULT '',
    kind String DEFAULT '',
    code String DEFAULT '',
    seq Int32 DEFAULT 0,
    exclusive Bool DEFAULT false,
    state String DEFAULT '',
    attrs String DEFAULT '{}',  -- JSON
    progress String DEFAULT '{}',  -- JSON
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    active Bool DEFAULT false,
    allowForceComplete Bool DEFAULT false,
    autoComplete Bool DEFAULT false,
    wave Int32 DEFAULT 0,
    forceCompleteTaskId String DEFAULT '',
    forceCompleted Bool DEFAULT false,
    subKind String DEFAULT '',
    label String DEFAULT '',
    
    -- Indexes for common query patterns
    INDEX idx_whId whId TYPE minmax GRANULARITY 1,
    INDEX idx_sessionId sessionId TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_code code TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_kind kind TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_state state TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_active active TYPE minmax GRANULARITY 1,
    INDEX idx_wave wave TYPE minmax GRANULARITY 1
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id)  -- id is globally unique
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop'
COMMENT 'WMS Tasks dimension table';

-- Add projection for common query pattern (sessionId, seq)
ALTER TABLE wms_tasks ADD PROJECTION IF NOT EXISTS by_session_seq (
    SELECT * ORDER BY (sessionId, seq)
);

-- Add projection for whId, kind pattern
ALTER TABLE wms_tasks ADD PROJECTION IF NOT EXISTS by_wh_kind (
    SELECT * ORDER BY (whId, kind, id)
);

-- Materialize the projections
ALTER TABLE wms_tasks MATERIALIZE PROJECTION by_session_seq;
ALTER TABLE wms_tasks MATERIALIZE PROJECTION by_wh_kind;