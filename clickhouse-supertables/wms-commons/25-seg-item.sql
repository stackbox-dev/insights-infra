-- ClickHouse table for WMS Segment Item
-- Dimension table for Segment Item information
-- Source: samadhan_prod.wms.public.seg_item

CREATE TABLE IF NOT EXISTS wms_seg_item
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '', 
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sessionId String DEFAULT '',
    insertionId String DEFAULT '',
    taskId String DEFAULT '',
    key String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    groupId String DEFAULT '',
    huId String DEFAULT '',
    containerId String DEFAULT '',
    assignedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    workerId String DEFAULT '',
    attrs String DEFAULT '{}',
    volume Float64 DEFAULT 0.0
)
ENGINE = ReplacingMergeTree(sessionCreatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;