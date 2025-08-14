-- ClickHouse table for WMS Inventory Weekly Cumulative Snapshots
-- Stores cumulative quantities at weekly intervals for performance optimization
-- Generated every Sunday at midnight for efficient time-series queries

CREATE TABLE IF NOT EXISTS wms_inventory_weekly_snapshot
(
    -- Snapshot metadata
    snapshot_timestamp DateTime COMMENT 'Timestamp of the snapshot (Sunday midnight)',
    snapshot_type String DEFAULT 'weekly' COMMENT 'Type of snapshot (weekly)',
    wh_id Int64 DEFAULT 0 COMMENT 'Warehouse ID',
    
    -- Core inventory identifiers
    hu_id String DEFAULT '' COMMENT 'Handling unit ID',
    hu_code String DEFAULT '' COMMENT 'Handling unit code',
    sku_id String DEFAULT '' COMMENT 'SKU ID',
    
    -- SKU enrichment fields
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
    
    -- Cumulative metrics at snapshot time
    cumulative_qty Int64 DEFAULT 0 COMMENT 'Total cumulative quantity from beginning of time to snapshot',
    total_event_count UInt64 DEFAULT 0 COMMENT 'Total number of events processed up to this snapshot',
    
    -- Latest event identifiers at snapshot time
    latest_hu_event_id String DEFAULT '',
    latest_quant_event_id String DEFAULT '',
    last_event_time DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3) COMMENT 'Timestamp of last event in this snapshot',
    
    -- Latest state information at snapshot time
    latest_event_type String DEFAULT '',
    latest_hu_state String DEFAULT '',
    latest_session_id String DEFAULT '',
    latest_task_id String DEFAULT '',
    latest_correlation_id String DEFAULT '',
    latest_effective_storage_id String DEFAULT '',
    
    -- Latest handling unit attributes
    hu_kind_id String DEFAULT '',
    hu_attrs String DEFAULT '{}',
    hu_lock_task_id String DEFAULT '',
    hu_effective_storage_id String DEFAULT '',
    
    -- Latest storage attributes
    storage_bin_description String DEFAULT '',
    storage_multi_sku Bool DEFAULT false,
    storage_multi_batch Bool DEFAULT false,
    storage_picking_position Int32 DEFAULT 0,
    storage_putaway_position Int32 DEFAULT 0,
    
    -- Latest SKU attributes
    sku_principal_id Int64 DEFAULT 0,
    sku_node_id Int64 DEFAULT 0,
    sku_product String DEFAULT '',
    sku_category_group String DEFAULT '',
    sku_fulfillment_type String DEFAULT '',
    sku_inventory_type String DEFAULT '',
    sku_l0_weight Float64 DEFAULT 0,
    sku_l0_volume Float64 DEFAULT 0,
    sku_active Bool DEFAULT false,
    
    -- Snapshot generation metadata
    generated_at DateTime64(3) DEFAULT now64(3) COMMENT 'When this snapshot was generated',
    
    -- Indexes for common query patterns
    INDEX idx_wh_id wh_id TYPE minmax GRANULARITY 1,
    INDEX idx_sku_code sku_code TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_hu_code hu_code TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_storage_bin_code storage_bin_code TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_storage_zone_code storage_zone_code TYPE bloom_filter(0.01) GRANULARITY 4,
    INDEX idx_sku_category sku_category TYPE bloom_filter(0.01) GRANULARITY 4,
    INDEX idx_sku_brand sku_brand TYPE bloom_filter(0.01) GRANULARITY 4
)
ENGINE = ReplacingMergeTree(generated_at)
PARTITION BY toYYYYMM(snapshot_timestamp)
ORDER BY (wh_id, snapshot_timestamp, hu_id, sku_id, uom, bucket, batch)
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop',
         min_age_to_force_merge_seconds = 180
COMMENT 'Weekly cumulative inventory snapshots with enriched dimension data';

-- Projection for inventory balance queries by SKU
ALTER TABLE wms_inventory_weekly_snapshot ADD PROJECTION proj_by_sku_snapshot (
    SELECT 
        snapshot_timestamp,
        wh_id,
        sku_id,
        sku_code,
        sku_name,
        sku_category,
        sku_brand,
        sum(cumulative_qty) AS total_qty
    GROUP BY snapshot_timestamp, wh_id, sku_id, sku_code, sku_name, sku_category, sku_brand
    ORDER BY (wh_id, sku_id, snapshot_timestamp)
);

-- Projection for zone/area inventory analysis
ALTER TABLE wms_inventory_weekly_snapshot ADD PROJECTION proj_by_zone_snapshot (
    SELECT 
        snapshot_timestamp,
        wh_id,
        storage_zone_code,
        storage_area_code,
        sku_category,
        sum(cumulative_qty) AS total_qty,
        count() AS position_count
    GROUP BY snapshot_timestamp, wh_id, storage_zone_code, storage_area_code, sku_category
    ORDER BY (wh_id, storage_zone_code, snapshot_timestamp)
);