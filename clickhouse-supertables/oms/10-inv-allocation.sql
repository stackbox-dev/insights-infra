-- ClickHouse table for OMS Inventory Allocation
-- Source: oms.public.inv_allocation

CREATE TABLE IF NOT EXISTS oms_inv_allocation
(
    id String DEFAULT '',
    inv_id String DEFAULT '',
    inv_line_id String DEFAULT '',
    allocation_line_id String DEFAULT '',
    order_code String DEFAULT '',
    trip_code String DEFAULT '',
    qty Int32 DEFAULT 0,
    node_id String DEFAULT '',
    created_at DateTime64(3) DEFAULT toDateTime64(0, 3),
    updated_at DateTime64(3) DEFAULT toDateTime64(0, 3)
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (id)
PARTITION BY toYYYYMM(created_at)
SETTINGS index_granularity = 8192;