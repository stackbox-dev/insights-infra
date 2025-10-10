-- ClickHouse table for WMS IRA Task Bin
-- Dimension table for IRA Task Bin information
-- Source: samadhan_prod.wms.public.ira_task_bin

CREATE TABLE IF NOT EXISTS wms_ira_task_bin
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    binId String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    transactionId String DEFAULT '',
    state String DEFAULT '',
    updatedBy String DEFAULT '',
    pickLockReleasedTaskIds String DEFAULT '[]',
    attrs String DEFAULT '{}',
    pickLockReleasedMovementDemandIds String DEFAULT '[]',
    recordNo Int64 DEFAULT 1,
    approvalState String DEFAULT '',
    recordedBy String DEFAULT '',
    recordedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    putLockReleasedTaskIds String DEFAULT '[]',
    provisionalPickItemsReleasedKeys String DEFAULT '[]'
)
ENGINE = ReplacingMergeTree(recordedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;