-- Monitoring queries for WMS Inventory Position system
-- Use these to track performance and data quality

-- 1. System Overview
SELECT 
    'System Health Check' as metric,
    (SELECT count() FROM wms_inventory_events_enriched) as raw_events,
    (SELECT count() FROM wms_inventory_hourly_position) as hourly_records,
    (SELECT count() FROM wms_inventory_weekly_snapshot) as snapshot_records,
    (SELECT max(hour_window) FROM wms_inventory_hourly_position) as latest_hour,
    (SELECT max(snapshot_timestamp) FROM wms_inventory_weekly_snapshot) as latest_snapshot;

-- 2. Query Performance Test (should be < 1 second)
SELECT 
    count() as positions,
    sum(quantity) as total_quantity,
    count(DISTINCT sku_code) as unique_skus,
    count(DISTINCT storage_zone_code) as zones,
    query_time,
    base_snapshot_time
FROM wms_inventory_position_at_time(wh_id=1, target_time=now())
FORMAT JSON;

-- 3. Data Freshness Check
SELECT 
    wh_id,
    max(last_event_time) as latest_event,
    now() - max(last_event_time) as lag_seconds,
    count() as positions
FROM wms_inventory_hourly_position
WHERE hour_window >= now() - INTERVAL 1 DAY
GROUP BY wh_id
ORDER BY wh_id;

-- 4. Weekly Snapshot Status
SELECT 
    snapshot_type,
    wh_id,
    snapshot_timestamp,
    records_count,
    generation_duration_seconds,
    status,
    created_at
FROM wms_inventory_snapshot_metadata
WHERE snapshot_date >= today() - INTERVAL 14 DAY
ORDER BY snapshot_timestamp DESC, wh_id;

-- 5. Duplicate Detection
WITH duplicates AS (
    SELECT 
        hu_event_id,
        quant_event_id,
        count() as duplicate_count
    FROM wms_inventory_events_enriched
    WHERE _ingested_at >= now() - INTERVAL 1 DAY
    GROUP BY hu_event_id, quant_event_id
    HAVING count() > 1
)
SELECT 
    count() as duplicate_pairs,
    sum(duplicate_count - 1) as extra_records
FROM duplicates;

-- 6. Storage Usage by Table
SELECT 
    table,
    formatReadableSize(sum(bytes)) as size,
    sum(rows) as rows,
    formatReadableSize(sum(bytes) / sum(rows)) as avg_row_size
FROM system.parts
WHERE database = currentDatabase()
  AND table IN ('wms_inventory_events_enriched', 'wms_inventory_hourly_position', 'wms_inventory_weekly_snapshot')
  AND active
GROUP BY table
ORDER BY sum(bytes) DESC;

-- 7. Hourly Event Volume Trend
SELECT 
    hour_window,
    wh_id,
    sum(event_count) as events,
    sum(hourly_qty_change) as net_qty_change,
    count() as unique_positions
FROM wms_inventory_hourly_position
WHERE hour_window >= now() - INTERVAL 24 HOUR
GROUP BY hour_window, wh_id
ORDER BY hour_window DESC, wh_id;

-- 8. Top Moving SKUs
SELECT 
    sku_code,
    sku_name,
    sum(abs(hourly_qty_change)) as total_movement,
    sum(hourly_qty_change) as net_change,
    count() as position_count
FROM wms_inventory_hourly_position
WHERE hour_window >= now() - INTERVAL 7 DAY
GROUP BY sku_code, sku_name
ORDER BY total_movement DESC
LIMIT 20;

-- 9. Dictionary Status Check
SELECT 
    name,
    status,
    origin,
    element_count,
    load_duration,
    last_successful_update_time,
    loading_start_time
FROM system.dictionaries
WHERE name = 'wms_snapshot_metadata_dict';

-- 10. Query Performance by Time Range
WITH performance_test AS (
    SELECT 
        'Last Hour' as time_range,
        now() - INTERVAL 1 HOUR as target_time,
        1 as wh_id
    UNION ALL
    SELECT 'Yesterday', now() - INTERVAL 1 DAY, 1
    UNION ALL
    SELECT 'Last Week', now() - INTERVAL 7 DAY, 1
    UNION ALL
    SELECT 'Last Month', now() - INTERVAL 30 DAY, 1
)
SELECT 
    time_range,
    target_time,
    -- Note: In real usage, measure actual query time
    (SELECT count() FROM wms_inventory_position_at_time(wh_id=wh_id, target_time=target_time)) as record_count
FROM performance_test;

-- 11. Data Quality - Zero Quantity Positions
SELECT 
    'Positions with zero quantity' as check_type,
    count() as count
FROM (
    SELECT 
        wh_id,
        hu_code,
        sku_code,
        sum(hourly_qty_change) as total_qty
    FROM wms_inventory_hourly_position
    GROUP BY wh_id, hu_code, sku_code
    HAVING total_qty = 0
);

-- 12. Snapshot Generation Health
SELECT 
    toStartOfWeek(snapshot_timestamp) as week,
    wh_id,
    max(generation_duration_seconds) as max_duration_sec,
    avg(generation_duration_seconds) as avg_duration_sec,
    max(records_count) as max_records,
    countIf(status = 'completed') as successful,
    countIf(status != 'completed') as failed
FROM wms_inventory_snapshot_metadata
WHERE snapshot_type = 'weekly'
GROUP BY week, wh_id
ORDER BY week DESC, wh_id;