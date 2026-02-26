-- ClickHouse table for WMS Segment Group
-- Dimension table for Segment Group information
-- Source: samadhan_prod.wms.public.seg_group

CREATE TABLE IF NOT EXISTS wms_seg_group
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '', 
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    taskSubKind String DEFAULT '',
    sortingStrategy String DEFAULT '',
    key String DEFAULT '',
    binId String DEFAULT '',
    zoneId String DEFAULT '',
    expectedCount Int32 DEFAULT 0
)
ENGINE = ReplacingMergeTree(expectedCount)
ORDER BY (id)
SETTINGS index_granularity = 8192;