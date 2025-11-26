-- ClickHouse table for Load Line
-- Dimension table for Load Line information
-- Source: tms.public.load_line

CREATE TABLE IF NOT EXISTS tms_lht_load_line
(
    id String DEFAULT '',            
    load_id String DEFAULT '',
    line_id String DEFAULT '',
    order_id String DEFAULT '',
    qty Int32 DEFAULT 0,
    active Bool DEFAULT true,
    node_id String DEFAULT '',
    created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(updated_at)       
PARTITION BY toYYYYMM(created_at)               
ORDER BY (id)                                
SETTINGS index_granularity = 8192;
