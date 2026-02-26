-- ClickHouse table for BBulk PTL Demand
-- Dimension table for bulk pick-to-light demand
-- Source: samadhan_prod.wms.public.bbulk_ptl_demand

CREATE TABLE IF NOT EXISTS wms_bbulk_ptl_demand
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '',
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sessionId String DEFAULT '',
    groupId String DEFAULT '',
    invoiceId String DEFAULT '',
    invoiceLineId String DEFAULT '',
    skuId String DEFAULT '',
    batch String DEFAULT '',
    uom String DEFAULT '',
    qty Int32 DEFAULT 0,
    priority Int32 DEFAULT 0,
    batchAllocationType String DEFAULT 'FIXED',
    omsAllocationId String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    parentDemandId String DEFAULT '',
    deactivatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(sessionCreatedAt)
ORDER BY (id)
SETTINGS index_granularity = 8192
COMMENT 'BBulk PTL Demand dimension table';