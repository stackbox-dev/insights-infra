-- ClickHouse table for WMS PL Inventory Count Plan Sequence
-- Dimension table for PL Inventory Count Plan Sequence information
-- Source: samadhan_prod.wms.public.pl_inv_cnt_plan_seq

CREATE TABLE IF NOT EXISTS wms_pl_inv_cnt_plan_seq
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    planId String DEFAULT '',
    areaId String DEFAULT '',
    zoneIds String DEFAULT '[]',
    sequence Int32 DEFAULT 0
)
ENGINE = ReplacingMergeTree()
ORDER BY (id)
SETTINGS index_granularity = 8192;