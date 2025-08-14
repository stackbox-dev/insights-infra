-- ClickHouse table for WMS Workstation Events Staging
-- Unified workstation events from multiple sources
-- Source: sbx_uat.wms.flink.workstation_events_staging

CREATE TABLE IF NOT EXISTS wms_workstation_events_staging
(
    -- Primary fields
    event_type String,
    event_source_id String,
    event_timestamp DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    
    -- Core fields
    wh_id Int64 DEFAULT 0,
    sku_id String DEFAULT '',
    hu_id String DEFAULT '',
    hu_code String DEFAULT '',
    batch_id String DEFAULT '',
    user_id String DEFAULT '',
    task_id String DEFAULT '',
    session_id String DEFAULT '',
    bin_id String DEFAULT '',
    
    -- Quantity fields
    primary_quantity Int64 DEFAULT 0,
    secondary_quantity Int64 DEFAULT 0,
    tertiary_quantity Int64 DEFAULT 0,
    
    -- Additional fields
    price String DEFAULT '',
    status_or_bucket String DEFAULT '',
    reason String DEFAULT '',
    sub_reason String DEFAULT '',
    deactivated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    
    
    -- Indexes for enrichment MV JOIN performance
    INDEX idx_wh_id wh_id TYPE minmax GRANULARITY 1,
    INDEX idx_event_timestamp event_timestamp TYPE minmax GRANULARITY 1,
    INDEX idx_hu_id hu_id TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_bin_id bin_id TYPE bloom_filter(0.01) GRANULARITY 1
)
ENGINE = ReplacingMergeTree(event_timestamp)
PARTITION BY toYYYYMM(event_timestamp)
ORDER BY (wh_id, event_type, event_source_id)
TTL toDateTime(deactivated_at) + INTERVAL 0 SECOND DELETE
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop',
         min_age_to_force_merge_seconds = 180
COMMENT 'WMS Workstation Events Staging data from Flink pipeline - Source table for enrichment';

-- Projections removed to prevent stale data issues in enrichment MVs
-- Enrichment MVs will use the main table data for fresh, complete results