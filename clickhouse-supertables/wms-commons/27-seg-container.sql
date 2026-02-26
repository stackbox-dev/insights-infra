-- ClickHouse table for WMS Segment Container
-- Dimension table for Segment Container information
-- Source: samadhan_prod.wms.public.seg_container

CREATE TABLE IF NOT EXISTS wms_seg_container
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '', 
    sessionId String DEFAULT '',
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    taskId String DEFAULT '',
    groupId String DEFAULT '',
    type String DEFAULT '',
    containerId String DEFAULT '',
    containerCode String DEFAULT '',
    active Bool DEFAULT false,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    workerId String DEFAULT '',
    usedCapacity Int32 DEFAULT 0,
    maxCapacity Int32 DEFAULT 0,
    usedVolume Float64 DEFAULT 0.0,
    maxVolume Float64 DEFAULT 0.0,
    itemVolume Float64 DEFAULT 0.0
)
ENGINE = ReplacingMergeTree(sessionCreatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;