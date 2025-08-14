-- ClickHouse table for WMS Handling Units
-- Dimension table for handling unit information
-- Source: sbx_uat.wms.public.handling_unit

CREATE TABLE IF NOT EXISTS wms_handling_units
(
    whId Int64 DEFAULT 0,
    id String,
    code String DEFAULT '',
    kindId String DEFAULT '',
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    storageId String DEFAULT '',
    outerHuId String DEFAULT '',
    state String DEFAULT '',
    attrs String DEFAULT '{}',  -- JSON
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    lockTaskId String DEFAULT '',
    effectiveStorageId String DEFAULT '',
    
    -- Indexes for common query patterns
    INDEX idx_whId whId TYPE minmax GRANULARITY 1,
    INDEX idx_code code TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_kindId kindId TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_sessionId sessionId TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_taskId taskId TYPE bloom_filter(0.01) GRANULARITY 1
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id)  -- id is globally unique
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop',
         min_age_to_force_merge_seconds = 180
COMMENT 'WMS Handling Units dimension table';
