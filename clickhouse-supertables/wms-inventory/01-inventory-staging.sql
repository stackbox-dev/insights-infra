-- ClickHouse table for WMS Inventory Events Staging
-- Raw inventory events from Flink processing pipeline
-- Source: sbx_uat.wms.flink.inventory_events_staging

CREATE TABLE IF NOT EXISTS wms_inventory_events_staging
(
    -- Handling unit event fields (aligned with Flink sink table)
    event_id String DEFAULT '',
    wh_id Int64 DEFAULT 0,
    seq Int64 DEFAULT 0,
    hu_id String DEFAULT '',
    event_type String DEFAULT '',
    `timestamp` DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    payload String DEFAULT '',
    attrs String DEFAULT '',
    session_id String DEFAULT '',
    task_id String DEFAULT '',
    correlation_id String DEFAULT '',
    storage_id String DEFAULT '',
    outer_hu_id String DEFAULT '',
    effective_storage_id String DEFAULT '',
    
    -- Handling unit quant event fields
    quant_event_id String DEFAULT '',
    sku_id String DEFAULT '',
    uom String DEFAULT '',
    bucket String DEFAULT '',
    batch String DEFAULT '',
    price String DEFAULT '',
    inclusion_status String DEFAULT '',
    locked_by_task_id String DEFAULT '',
    lock_mode String DEFAULT '',
    qty_added Int32 DEFAULT 0,
    quant_iloc String DEFAULT '',  -- Added to match Flink sink structure
    
    -- Indexes for enrichment MV JOIN performance
    INDEX idx_wh_id wh_id TYPE minmax GRANULARITY 1,
    INDEX idx_hu_id hu_id TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_effective_storage_id effective_storage_id TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_sku_id sku_id TYPE bloom_filter(0.01) GRANULARITY 1
)
ENGINE = ReplacingMergeTree(`timestamp`)
PARTITION BY toYYYYMM(`timestamp`)
ORDER BY (wh_id, `timestamp`, event_id, quant_event_id)
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop',
         min_age_to_force_merge_seconds = 180
COMMENT 'WMS Inventory Events Staging from Flink pipeline - Source table for enrichment';

