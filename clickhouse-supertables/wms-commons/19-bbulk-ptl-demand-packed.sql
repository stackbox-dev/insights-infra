-- ClickHouse table for WMS Breakbulk PTL Demand Packed
-- Dimension table for Breakbulk PTL Demand Packed information
-- Source: samadhan_prod.wms.public.bbulk_ptl_demand_packed

CREATE TABLE IF NOT EXISTS wms_bbulk_ptl_demand_packed
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '', 
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    zoneId String DEFAULT '',
    groupId String DEFAULT '',
    demandId String DEFAULT '',
    visitId String DEFAULT '',
    visitItemId String DEFAULT '',
    binAssignmentId String DEFAULT '',
    binId String DEFAULT '',
    chuId String DEFAULT '',
    chuKindId String DEFAULT '',
    chuKind String DEFAULT '',
    skuId String DEFAULT '',
    batch String DEFAULT '',
    uom String DEFAULT '',
    qty Int32 DEFAULT 0,
    packedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    packedBy String DEFAULT ''
)
ENGINE = ReplacingMergeTree(sessionCreatedAt)
PARTITION BY toYYYYMM(packedAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;