-- Monitoring queries for WMS Inventory Position system
-- Use these to track performance and data quality

-- 1. System Overview
SELECT 
    'System Health Check' as metric,
    (SELECT count() FROM wms_inventory_events_enriched) as raw_events,
    (SELECT count(DISTINCT snapshot_timestamp) FROM wms_inventory_snapshot) as total_snapshots,
    (SELECT max(snapshot_timestamp) FROM wms_inventory_snapshot) as latest_snapshot,
    (SELECT min(snapshot_timestamp) FROM wms_inventory_snapshot) as earliest_snapshot;

-- 2. Snapshot Status
SELECT 
    snapshot_timestamp,
    count(*) as inventory_positions,
    sum(cumulative_qty) as total_quantity,
    sum(total_event_count) as total_events,
    max(_created_at) as created_at
FROM wms_inventory_snapshot
GROUP BY snapshot_timestamp
ORDER BY snapshot_timestamp DESC
LIMIT 20;

-- 3. Data Freshness Check
SELECT 
    wh_id,
    max(last_event_time) as latest_event,
    now() - max(last_event_time) as lag_seconds,
    count(DISTINCT snapshot_timestamp) as snapshots,
    count() as total_positions
FROM wms_inventory_snapshot
WHERE snapshot_timestamp >= now() - INTERVAL 7 DAY
GROUP BY wh_id
ORDER BY wh_id;

-- 4. Storage Usage by Table
SELECT 
    table,
    formatReadableSize(sum(bytes)) as size,
    sum(rows) as rows,
    formatReadableSize(sum(bytes) / sum(rows)) as avg_row_size
FROM system.parts
WHERE database = currentDatabase()
  AND table IN ('wms_inventory_events_enriched', 'wms_inventory_snapshot')
  AND active
GROUP BY table
ORDER BY sum(bytes) DESC;

-- 5. Snapshot Interval Analysis
SELECT 
    snapshot_timestamp,
    lag(snapshot_timestamp) OVER (ORDER BY snapshot_timestamp) as prev_snapshot,
    dateDiff('hour', lag(snapshot_timestamp) OVER (ORDER BY snapshot_timestamp), snapshot_timestamp) as hours_between
FROM (
    SELECT DISTINCT snapshot_timestamp 
    FROM wms_inventory_snapshot
    ORDER BY snapshot_timestamp DESC
    LIMIT 20
)
ORDER BY snapshot_timestamp DESC;

-- 6. Top Moving SKUs (from latest snapshot)
WITH latest_snapshot AS (
    SELECT max(snapshot_timestamp) as ts FROM wms_inventory_snapshot
)
SELECT 
    sku_code,
    sku_name,
    sum(abs(cumulative_qty)) as total_quantity,
    count() as position_count,
    count(DISTINCT storage_bin_code) as unique_locations
FROM wms_inventory_snapshot
WHERE snapshot_timestamp = (SELECT ts FROM latest_snapshot)
GROUP BY sku_code, sku_name
ORDER BY total_quantity DESC
LIMIT 20;

-- 7. Query Performance Test - Position at Time
SELECT 
    count() as positions,
    sum(quantity) as total_quantity,
    count(DISTINCT sku_code) as unique_skus,
    count(DISTINCT storage_zone_code) as zones,
    query_time,
    base_snapshot_time
FROM wms_inventory_position_at_time(wh_id=4012, target_time=now())
FORMAT JSON;

-- 8. Missing Snapshot Detection (for daily snapshots)
WITH 
expected_daily AS (
    SELECT toStartOfHour(toStartOfDay(min(snapshot_timestamp)) + INTERVAL number DAY) as expected_time
    FROM wms_inventory_snapshot
    CROSS JOIN numbers(dateDiff('day', min(snapshot_timestamp), max(snapshot_timestamp)) + 1)
),
actual AS (
    SELECT DISTINCT toStartOfHour(snapshot_timestamp) as actual_time
    FROM wms_inventory_snapshot
)
SELECT 
    'Missing Daily Snapshots' as check_type,
    count() as missing_count,
    groupArray(formatDateTime(expected_time, '%Y-%m-%d'))[1:10] as first_10_missing
FROM expected_daily
LEFT JOIN actual ON expected_time = actual_time
WHERE actual_time IS NULL
  AND expected_time <= now();