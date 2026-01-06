-- ClickHouse table for WMS Task Worker Assignment
-- Dimension table for Task Worker Assignment information
-- Source: digitaldc_prod.wms.public.task_worker_assignment

CREATE TABLE IF NOT EXISTS wms_task_worker_assignment
(
    taskId String DEFAULT '',
    workerId String DEFAULT '',
    assignedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    attrs String DEFAULT '',
    whId Int64 DEFAULT 0,
    mheId String DEFAULT ''
)
ENGINE = ReplacingMergeTree(assignedAt)
ORDER BY (taskId, workerId)
SETTINGS index_granularity = 8192;