CREATE TABLE IF NOT EXISTS oms_shipment_output (
    id String DEFAULT '',
    reference_code String DEFAULT '',
    node_id String DEFAULT '',
    delivery_line_no String DEFAULT '',
    partner_code String DEFAULT '',
    customer_code String DEFAULT '',
    drop_location_code String DEFAULT '',
    drop_location_name String DEFAULT '',
    product String DEFAULT '',
    sku String DEFAULT '',
    qty Int32 DEFAULT 0,
    order_no String DEFAULT '',
    drop_location_beat String DEFAULT '',
    pickup_location_code String DEFAULT '',
    delivery_sequence Int32 DEFAULT 0,
    vehicle String DEFAULT '',
    vehicle_type String DEFAULT '',
    trip_code String DEFAULT '',
    trip_sequence Int32 DEFAULT 0,
    trip_type String DEFAULT '',
    trip_code_reference String DEFAULT '',
    plan_type String DEFAULT '',
    plan_code String DEFAULT '',
    payment_type String DEFAULT '',
    active Bool DEFAULT true,
    created_at DateTime64(6) DEFAULT toDateTime64(0, 6),
    last_updated_at DateTime64(6) DEFAULT toDateTime64(0, 6)
) ENGINE = ReplacingMergeTree(last_updated_at)
ORDER BY (id)
PARTITION BY toYYYYMM(created_at)
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop';