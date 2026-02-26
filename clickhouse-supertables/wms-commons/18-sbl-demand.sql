-- ClickHouse table for WMS SBL Demand
-- Dimension table for SBL Demand information
-- Source: samadhan_prod.wms.public.sbl_demand

CREATE TABLE IF NOT EXISTS wms_sbl_demand
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '', 
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    zoneId String DEFAULT '',
    binId String DEFAULT '',
    invoiceId String DEFAULT '',
    skuId String DEFAULT '',
    batch String DEFAULT '',
    uom String DEFAULT '',
    qty Int32 DEFAULT 0,
    priority Int32 DEFAULT 0,
    batchAllocationType String DEFAULT '',
    omsAllocationId String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    invoiceLineId String DEFAULT '',
)
ENGINE = ReplacingMergeTree(sessionCreatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;

