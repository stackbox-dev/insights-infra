-- ClickHouse table for Pick Drop Mapping
-- Source: public.pd_pick_drop_mapping

CREATE TABLE IF NOT EXISTS wms_pd_pick_drop_mapping
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    pickItemId String DEFAULT '',
    dropItemId String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    PRIMARY KEY (id)
)
ENGINE = ReplacingMergeTree(createdAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;
