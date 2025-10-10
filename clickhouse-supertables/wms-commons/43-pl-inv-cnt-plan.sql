-- ClickHouse table for WMS PL Inventory Count Plan
-- Dimension table for Inventory Count Plan information
-- Source: samadhan_prod.wms.public.pl_inv_cnt_plan

CREATE TABLE IF NOT EXISTS wms_pl_inv_cnt_plan
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    active Bool DEFAULT false
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;