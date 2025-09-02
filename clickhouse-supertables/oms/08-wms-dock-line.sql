CREATE TABLE IF NOT EXISTS oms_wms_dock_line (
    id String DEFAULT '',
    node_id String DEFAULT '',
    customer String DEFAULT '',
    partner String DEFAULT '',
    allocation_id String DEFAULT '',
    allocation_line_id String DEFAULT '',
    warehouse String DEFAULT '',
    location String DEFAULT '',
    sku String DEFAULT '',
    uom String DEFAULT '',
    batch String DEFAULT '',
    qty Int32 DEFAULT 0,
    xdock String DEFAULT '',
    mm_trip_code String DEFAULT '',
    mm_vehicle_no String DEFAULT '',
    lm_trip_code String DEFAULT '',
    dock_submission_scan_time DateTime64(3) DEFAULT toDateTime64(0, 3),
    volume_items Float64 DEFAULT 0.0,
    volume_total Float64 DEFAULT 0.0,
    weight_items Float64 DEFAULT 0.0,
    weight_total Float64 DEFAULT 0.0,
    hu_code String DEFAULT '',
    hu_type String DEFAULT '',
    created_at DateTime64(3) DEFAULT toDateTime64(0, 3),
    active Bool DEFAULT true,
    vehicle_type String DEFAULT '',
    transporter_code String DEFAULT '',
    transporter_name String DEFAULT ''
) ENGINE = ReplacingMergeTree(created_at)
ORDER BY (id)
PARTITION BY toYYYYMM(created_at)
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop';