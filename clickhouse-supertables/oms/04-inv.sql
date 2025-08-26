CREATE TABLE IF NOT EXISTS oms_inv (
    id String DEFAULT '',
    node_id String DEFAULT '',
    allocation_id String DEFAULT '',
    code String DEFAULT '',
    `type` String DEFAULT '',
    name String DEFAULT '',
    sold_to String DEFAULT '',
    ship_to String DEFAULT '',
    delivery_date Int32 DEFAULT 0,
    delivery_date_actual Date DEFAULT toDate('1970-01-01'),
    order_date Int32 DEFAULT 0,
    order_date_actual Date DEFAULT toDate('1970-01-01'),
    validity_date Int32 DEFAULT 0,
    validity_date_actual Date DEFAULT toDate('1970-01-01'),
    channel String DEFAULT '',
    vehicle String DEFAULT '',
    active Bool DEFAULT true,
    created_at DateTime64(6) DEFAULT toDateTime64(0, 6),
    last_updated_at DateTime64(6) DEFAULT toDateTime64(0, 6),
    cancellation_requested_at DateTime64(6) DEFAULT toDateTime64(0, 6),
    vehicle_type String DEFAULT '',
    transporter_code String DEFAULT '',
    transporter_name String DEFAULT ''
) ENGINE = ReplacingMergeTree(last_updated_at)
ORDER BY (id)
PARTITION BY toYYYYMM(created_at)
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop';