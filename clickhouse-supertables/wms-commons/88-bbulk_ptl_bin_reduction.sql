-- ClickHouse table for WMS bbulk_ptl_bin_reduction
-- Fact table for bulk PTL bin reduction events
-- Source: samadhan_prod.wms.public.bbulk_ptl_bin_reduction

CREATE TABLE IF NOT EXISTS wms_bbulk_ptl_bin_reduction
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '',
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    zoneId String DEFAULT '',
    groupId String DEFAULT '',
    chuId String DEFAULT '',
    visitId String DEFAULT '',
    chuAssignmentId String DEFAULT '',
    binAssignmentId String DEFAULT '',
    qty Int32 DEFAULT 0,
    newQty Int32 DEFAULT 0,
    reason String DEFAULT '',
    reducedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    reducedBy String DEFAULT ''
)
ENGINE = ReplacingMergeTree(reducedAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;