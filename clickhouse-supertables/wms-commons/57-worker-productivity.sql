-- ClickHouse table for WMS Worker Productivity
-- Dimension table for Worker Productivity information
-- Source: samadhan_prod.wms.public.worker_productivity

CREATE TABLE IF NOT EXISTS wms_worker_productivity
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    workerId String DEFAULT '',
    date Date DEFAULT toDate('1970-01-01'),
    taskId String DEFAULT '',
    activeTime Int32 DEFAULT 0,
    qtyL2 Int32 DEFAULT 0,
    qtyL0 Int32 DEFAULT 0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)

)
ENGINE = ReplacingMergeTree(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;
