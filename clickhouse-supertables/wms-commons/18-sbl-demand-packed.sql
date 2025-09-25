-- ClickHouse table for WMS SBL Demand Packed
-- Dimension table for SBL Demand Packed information
-- Source: samadhan_prod.wms.public.sbl_demand_packed

CREATE TABLE IF NOT EXISTS wms_sbl_demand_packed
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '', 
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    zoneId String DEFAULT '',
    demandId String DEFAULT '',
    inventoryHUId String DEFAULT '',
    visitId String DEFAULT '',
    chuAssignmentId String DEFAULT '',
    chuId String DEFAULT '',
    chuKindId String DEFAULT '',
    chuKind String DEFAULT '',
    skuId String DEFAULT '',
    batch String DEFAULT '',
    uom String DEFAULT '',
    qty Int32 DEFAULT 0,
    packedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    packedBy String DEFAULT '',
    binAssignmentId String DEFAULT '',
    visitItemId String DEFAULT ''
)
ENGINE = ReplacingMergeTree(packedAt)
PARTITION BY toYYYYMM(sessionCreatedAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;