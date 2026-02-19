-- ClickHouse table for Storage Area
-- Source: public.storage_area

CREATE TABLE IF NOT EXISTS wms_storage_area
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    code String DEFAULT '',
    description String DEFAULT '',
    type String DEFAULT '',
    active Bool DEFAULT true,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    rollingDays Int32 DEFAULT 0,
    PRIMARY KEY (id)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;