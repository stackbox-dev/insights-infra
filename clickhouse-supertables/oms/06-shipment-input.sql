CREATE TABLE IF NOT EXISTS oms_shipment_input (
    id String DEFAULT '',
    asn_reference String DEFAULT '',
    delivery_line_code String DEFAULT '',
    partner_code String DEFAULT '',
    customer_code String DEFAULT '',
    customer_child_code String DEFAULT '',
    priority Int32 DEFAULT 0,
    product_code String DEFAULT '',
    sku String DEFAULT '',
    length Int32 DEFAULT 0,
    width Int32 DEFAULT 0,
    height Int32 DEFAULT 0,
    weight Int64 DEFAULT 0,
    quantity Int32 DEFAULT 0,
    order_code String DEFAULT '',
    plan_type String DEFAULT '',
    in_crate_volume Int64 DEFAULT 0,
    in_crate_weight Int64 DEFAULT 0,
    warehouse String DEFAULT '',
    plan_code String DEFAULT '',
    kind_type String DEFAULT '',
    node_id String DEFAULT '',
    allocation_id String DEFAULT '',
    allocation_line_id String DEFAULT '',
    active Bool DEFAULT true,
    created_at DateTime64(3) DEFAULT toDateTime64(0, 3),
    last_updated_at DateTime64(3) DEFAULT toDateTime64(0, 3)
) ENGINE = ReplacingMergeTree(last_updated_at)
ORDER BY (id)
PARTITION BY toYYYYMM(created_at)
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop';