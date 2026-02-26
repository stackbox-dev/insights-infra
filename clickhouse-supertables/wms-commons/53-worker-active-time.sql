-- ClickHouse table for WMS Worker Active Time
-- Dimension table for Worker Active Time information
-- Source: samadhan_prod.wms.public.worker_active_time

CREATE TABLE IF NOT EXISTS wms_worker_active_time
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    workerId String DEFAULT '',
    date Date DEFAULT toDate('1970-01-01'),
    taskId String DEFAULT '',
    fromTime DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    toTime DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)

)
ENGINE = ReplacingMergeTree(fromTime)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;
