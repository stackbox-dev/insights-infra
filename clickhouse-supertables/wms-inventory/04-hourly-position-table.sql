-- ClickHouse table for WMS Inventory Hourly Position
-- Stores hourly aggregated inventory positions with delta tracking
-- Optimized for time-series analysis and cumulative snapshot generation

CREATE TABLE IF NOT EXISTS wms_inventory_hourly_position
(
    -- Time and warehouse
    hour_window DateTime COMMENT 'Hour window for this aggregation',
    wh_id Int64 DEFAULT 0 COMMENT 'Warehouse ID',
    
    -- Core inventory identifiers
    hu_id String DEFAULT '' COMMENT 'Handling unit ID',
    hu_code String DEFAULT '' COMMENT 'Handling unit code',
    sku_id String DEFAULT '' COMMENT 'SKU ID',
    
    -- SKU enrichment fields for aggregation
    sku_code String DEFAULT '' COMMENT 'SKU code',
    sku_name String DEFAULT '' COMMENT 'SKU name',
    sku_category String DEFAULT '' COMMENT 'SKU category',
    sku_brand String DEFAULT '' COMMENT 'SKU brand',
    sku_sub_brand String DEFAULT '' COMMENT 'SKU sub-brand',
    
    -- Inventory attributes (position keys)
    uom String DEFAULT '' COMMENT 'Unit of measure',
    bucket String DEFAULT '' COMMENT 'Inventory bucket/category',
    batch String DEFAULT '' COMMENT 'Batch identifier',
    price String DEFAULT '' COMMENT 'Price bucket',
    inclusion_status String DEFAULT '' COMMENT 'Inclusion status for inventory',
    locked_by_task_id String DEFAULT '' COMMENT 'Task that has locked this inventory',
    lock_mode String DEFAULT '' COMMENT 'Lock mode (shared/exclusive)',
    
    -- Storage location from enrichment
    storage_bin_code String DEFAULT '' COMMENT 'Storage bin code',
    storage_zone_code String DEFAULT '' COMMENT 'Storage zone code',
    storage_area_code String DEFAULT '' COMMENT 'Storage area code',
    storage_aisle String DEFAULT '' COMMENT 'Storage aisle',
    storage_bay String DEFAULT '' COMMENT 'Storage bay',
    storage_level String DEFAULT '' COMMENT 'Storage level',
    
    -- Aggregated metrics for this hour (delta only, not cumulative)
    hourly_qty_change SimpleAggregateFunction(sum, Int32) COMMENT 'Net quantity change in this hour',
    event_count SimpleAggregateFunction(sum, UInt64) COMMENT 'Number of events in this hour',
    
    -- Latest event identifiers
    latest_hu_event_id SimpleAggregateFunction(anyLast, String),
    latest_quant_event_id SimpleAggregateFunction(anyLast, String),
    
    -- Event time boundaries
    first_event_time SimpleAggregateFunction(min, DateTime64(3)) COMMENT 'Earliest event in this hour',
    last_event_time SimpleAggregateFunction(max, DateTime64(3)) COMMENT 'Latest event in this hour',
    
    -- Latest state information
    latest_event_type SimpleAggregateFunction(anyLast, String),
    latest_hu_state SimpleAggregateFunction(anyLast, String),
    latest_session_id SimpleAggregateFunction(anyLast, String),
    latest_task_id SimpleAggregateFunction(anyLast, String),
    latest_correlation_id SimpleAggregateFunction(anyLast, String),
    latest_effective_storage_id SimpleAggregateFunction(anyLast, String),
    
    -- Latest handling unit attributes
    hu_kind_id SimpleAggregateFunction(anyLast, String),
    hu_attrs SimpleAggregateFunction(anyLast, String),
    hu_lock_task_id SimpleAggregateFunction(anyLast, String),
    hu_effective_storage_id SimpleAggregateFunction(anyLast, String),
    
    -- Latest storage attributes
    storage_bin_description SimpleAggregateFunction(anyLast, String),
    storage_multi_sku SimpleAggregateFunction(anyLast, Bool),
    storage_multi_batch SimpleAggregateFunction(anyLast, Bool),
    storage_picking_position SimpleAggregateFunction(anyLast, Int32),
    storage_putaway_position SimpleAggregateFunction(anyLast, Int32),
    
    -- Latest SKU attributes
    sku_principal_id SimpleAggregateFunction(anyLast, Int64),
    sku_node_id SimpleAggregateFunction(anyLast, Int64),
    sku_product SimpleAggregateFunction(anyLast, String),
    sku_category_group SimpleAggregateFunction(anyLast, String),
    sku_fulfillment_type SimpleAggregateFunction(anyLast, String),
    sku_inventory_type SimpleAggregateFunction(anyLast, String),
    sku_l0_weight SimpleAggregateFunction(anyLast, Float64),
    sku_l0_volume SimpleAggregateFunction(anyLast, Float64),
    sku_active SimpleAggregateFunction(anyLast, Bool),
    
    -- Indexes for common query patterns
    INDEX idx_wh_id wh_id TYPE minmax GRANULARITY 1,
    INDEX idx_sku_code sku_code TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_hu_code hu_code TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_storage_bin_code storage_bin_code TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_storage_zone_code storage_zone_code TYPE bloom_filter(0.01) GRANULARITY 4,
    INDEX idx_sku_category sku_category TYPE bloom_filter(0.01) GRANULARITY 4,
    INDEX idx_sku_brand sku_brand TYPE bloom_filter(0.01) GRANULARITY 4
)
ENGINE = AggregatingMergeTree()
PARTITION BY toYYYYMM(hour_window)
ORDER BY (wh_id, hour_window, hu_id, sku_id, uom, bucket, batch)
SETTINGS index_granularity = 8192,
         min_age_to_force_merge_seconds = 180
COMMENT 'Hourly aggregated inventory positions with enriched dimension data';

-- Projection for time-series queries by SKU
ALTER TABLE wms_inventory_hourly_position ADD PROJECTION proj_by_sku_time (
    SELECT 
        hour_window,
        wh_id,
        sku_id,
        sku_code,
        sku_name,
        sku_category,
        sku_brand,
        sum(hourly_qty_change) AS total_qty_change,
        sum(event_count) AS total_events
    GROUP BY hour_window, wh_id, sku_id, sku_code, sku_name, sku_category, sku_brand
    ORDER BY (wh_id, sku_id, hour_window)
);

-- Projection for zone/area analytics
ALTER TABLE wms_inventory_hourly_position ADD PROJECTION proj_by_zone_time (
    SELECT 
        hour_window,
        wh_id,
        storage_zone_code,
        storage_area_code,
        sku_category,
        sum(hourly_qty_change) AS total_qty_change,
        sum(event_count) AS total_events
    GROUP BY hour_window, wh_id, storage_zone_code, storage_area_code, sku_category
    ORDER BY (wh_id, storage_zone_code, hour_window)
);