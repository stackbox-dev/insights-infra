CREATE TABLE IF NOT EXISTS oms_inv (
    id String DEFAULT '',
    node_id String DEFAULT '',
    allocation_id String DEFAULT '',
    code String DEFAULT '',
    `type` String DEFAULT '',
    name String DEFAULT '',
    sold_to String DEFAULT '',
    ship_to String DEFAULT '',
    delivery_date Date DEFAULT toDate('1970-01-01'),
    order_date Date DEFAULT toDate('1970-01-01'),
    validity_date Date DEFAULT toDate('1970-01-01'),
    channel String DEFAULT '',
    vehicle String DEFAULT '',
    active Bool DEFAULT true,
    created_at DateTime64(3) DEFAULT toDateTime64(0, 3),
    last_updated_at DateTime64(3) DEFAULT toDateTime64(0, 3),
    cancellation_requested_at DateTime64(3) DEFAULT toDateTime64(0, 3),
    vehicle_type String DEFAULT '',
    transporter_code String DEFAULT '',
    transporter_name String DEFAULT ''
) ENGINE = ReplacingMergeTree(last_updated_at)
ORDER BY (id)
PARTITION BY toYYYYMM(created_at)
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop';