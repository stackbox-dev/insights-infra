CREATE TABLE IF NOT EXISTS wms_handling_unit_event
(
    whId Int64 DEFAULT 0,
    id String,
    seq Int64 DEFAULT 0,
    huId String DEFAULT '',
    type String DEFAULT '',
    timestamp DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    payload String DEFAULT '{}',
    attrs String DEFAULT '{}',
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    correlationId String DEFAULT '',
    storageId String DEFAULT '',
    outerHuId String DEFAULT '',
    effectiveStorageId String DEFAULT ''
)
ENGINE = ReplacingMergeTree(timestamp)
ORDER BY (id, seq)
SETTINGS index_granularity = 8192;