-- ClickHouse table for ORD
-- Dimension table for Order information
-- Source: tms.public.ord

CREATE TABLE IF NOT EXISTS tms_ord
(
    id String DEFAULT '',
    code String DEFAULT '',
    soldTo String DEFAULT '',
    type String DEFAULT '',
    deliveryDate DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    netValue Int32 DEFAULT 0,
    customer String DEFAULT '',
    orderedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    salesmanId String DEFAULT '',
    nodeId String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    destination String DEFAULT '',
    customerName String DEFAULT '',
    customerAddress String DEFAULT ''
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;