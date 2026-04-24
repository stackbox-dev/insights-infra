-- ClickHouse table for WMS Task Event
-- Dimension table for task event information
-- Source: sbx_uat.wms.public.task_event

CREATE TABLE IF NOT EXISTS wms_task_event
(
    whId Int64 DEFAULT 0,
    id String,
    taskId String DEFAULT '',
    kind String DEFAULT '',
    scanPayload String DEFAULT '{}',  -- JSON
    `timestamp` DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),

    -- Indexes for common query patterns
    INDEX idx_whId whId TYPE minmax GRANULARITY 1,
    INDEX idx_taskId taskId TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_kind kind TYPE bloom_filter(0.01) GRANULARITY 1
)
ENGINE = ReplacingMergeTree(createdAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)  -- id is globally unique (UUID)
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop',
         min_age_to_force_merge_seconds = 180
COMMENT 'WMS Task Event dimension table';
