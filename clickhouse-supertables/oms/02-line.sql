CREATE TABLE IF NOT EXISTS oms_line (
    id String DEFAULT '',
    order_id String DEFAULT '',
    code String DEFAULT '',
    txn_id String DEFAULT '',
    product String DEFAULT '',
    priority Int32 DEFAULT 0,
    qty Int32 DEFAULT 0,
    target_met Bool DEFAULT false,
    mrp Float64 DEFAULT 0.0,
    tags String DEFAULT '',
    tag_1 String DEFAULT '',
    tag_2 String DEFAULT '',
    tag_3 String DEFAULT '',
    tag_4 String DEFAULT '',
    sku String DEFAULT '',
    created_at DateTime64(6) DEFAULT toDateTime64(0, 6),
    node_id String DEFAULT ''
) ENGINE = ReplacingMergeTree(created_at)
ORDER BY (id)
PARTITION BY toYYYYMM(created_at)
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop';