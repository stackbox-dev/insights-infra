-- ClickHouse table for INB Unload Item
-- Source: public.inb_unload_item

CREATE TABLE IF NOT EXISTS wms_inb_unload_item
(
    whId Int64 DEFAULT 0,
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    id String DEFAULT '',
    huId String DEFAULT '',
    huCode String DEFAULT '',
    qty Int32 DEFAULT 0,
    stagingBinId String DEFAULT '',
    receivedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    receivedBy String DEFAULT '',
    movedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    movedBy String DEFAULT '',
    processedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    PRIMARY KEY (id)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;