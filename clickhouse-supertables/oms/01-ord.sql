CREATE TABLE IF NOT EXISTS oms_ord (
    id String DEFAULT '',
    code String DEFAULT '',
    txn_id String DEFAULT '',
    code_1 String DEFAULT '',
    code_2 String DEFAULT '',
    code_3 String DEFAULT '',
    customer String DEFAULT '',
    customer_child String DEFAULT '',
    supplier String DEFAULT '',
    partner String DEFAULT '',
    salesman String DEFAULT '',
    placed_at DateTime64(6) DEFAULT toDateTime64(0, 6),
    created_at DateTime64(6) DEFAULT toDateTime64(0, 6),
    first_allocation_date Int32 DEFAULT 0,
    first_allocation_date_actual Date DEFAULT toDate('1970-01-01'),
    last_allocation_date Int32 DEFAULT 0,
    last_allocation_date_actual Date DEFAULT toDate('1970-01-01'),
    requested_delivery_date DateTime64(6) DEFAULT toDateTime64(0, 6),
    source String DEFAULT '',
    priority Int32 DEFAULT 0,
    delivery_type String DEFAULT '',
    payments String DEFAULT '',
    requested_mode_of_payment String DEFAULT '',
    tags String DEFAULT '',
    net_value Float64 DEFAULT 0.0,
    node_id String DEFAULT '',
    is_abnormal Bool DEFAULT false
) ENGINE = ReplacingMergeTree(created_at)
ORDER BY (id)
PARTITION BY toYYYYMM(created_at)
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop';