-- OMS Allocation Run table
-- Populated from topic: samadhan_prod.oms.public.allocation_run

CREATE TABLE IF NOT EXISTS oms_allocation_run (
    id String DEFAULT '',
    node_id String DEFAULT '',
    active Bool DEFAULT true,
    created_at DateTime64(3) DEFAULT now64(3),
    __source_ts_ms Int64 DEFAULT 0
) ENGINE = ReplacingMergeTree(__source_ts_ms)
ORDER BY (id)
SETTINGS index_granularity = 8192;