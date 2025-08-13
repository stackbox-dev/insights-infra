-- ClickHouse table for WMS Inventory Staging Events
-- Raw inventory events from Flink processing pipeline
-- Source: sbx_uat.wms.flink.inventory_events_staging

CREATE TABLE IF NOT EXISTS wms_inventory_staging
(
    -- Handling unit event fields
    hu_event_id String,
    wh_id Int64 DEFAULT 0,
    hu_event_seq Int64 DEFAULT 0,
    hu_id String DEFAULT '',
    hu_event_type String DEFAULT '',
    hu_event_timestamp DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    hu_event_payload String DEFAULT '',
    hu_event_attrs String DEFAULT '',
    session_id String DEFAULT '',
    task_id String DEFAULT '',
    correlation_id String DEFAULT '',
    storage_id String DEFAULT '',
    outer_hu_id String DEFAULT '',
    effective_storage_id String DEFAULT '',
    
    -- Handling unit quant event fields
    quant_event_id String,
    sku_id String DEFAULT '',
    uom String DEFAULT '',
    bucket String DEFAULT '',
    batch String DEFAULT '',
    price String DEFAULT '',
    inclusion_status String DEFAULT '',
    locked_by_task_id String DEFAULT '',
    lock_mode String DEFAULT '',
    qty_added Int32 DEFAULT 0,
    quant_iloc String DEFAULT '',
    
    -- Indexes for enrichment MV JOIN performance
    INDEX idx_wh_id wh_id TYPE minmax GRANULARITY 1,
    INDEX idx_hu_id hu_id TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_effective_storage_id effective_storage_id TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_sku_id sku_id TYPE bloom_filter(0.01) GRANULARITY 1
)
ENGINE = ReplacingMergeTree(hu_event_timestamp)
PARTITION BY toYYYYMM(hu_event_timestamp)
ORDER BY (wh_id, hu_event_timestamp, hu_event_id, quant_event_id)
SETTINGS index_granularity = 8192
COMMENT 'WMS Inventory Staging Events from Flink pipeline - Source table for enrichment';

-- Projection optimized for enrichment MV access pattern
ALTER TABLE wms_inventory_staging ADD PROJECTION proj_for_enrichment (
    SELECT *
    ORDER BY (wh_id, hu_event_id, quant_event_id)
);