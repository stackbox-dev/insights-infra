-- ClickHouse table for WMS PL Inventory Count Plan Cycle
-- Dimension table for PL Inventory Count Plan Cycle information
-- Source: samadhan_prod.wms.public.pl_inv_cnt_plan_cycle

CREATE TABLE IF NOT EXISTS wms_pl_inv_cnt_plan_cycle
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    planId String DEFAULT '',
    seqId String DEFAULT '',
    cycleId String DEFAULT '',
    sequence Int32 DEFAULT 0,
    cycleCount Int32 DEFAULT 0,
    plInvCntSessionId String DEFAULT '',
    plInvCntSessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(plInvCntSessionCreatedAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;
