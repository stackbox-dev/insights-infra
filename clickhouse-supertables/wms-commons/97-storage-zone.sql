-- ClickHouse table for Storage Zone
-- Source: public.storage_zone

CREATE TABLE IF NOT EXISTS wms_storage_zone
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    code String DEFAULT '',
    description String DEFAULT '',
    face String DEFAULT '',
    areaId String DEFAULT '',
    active Bool DEFAULT true,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    peripheral Bool DEFAULT false,
    surveillanceConfig String DEFAULT '',
    PRIMARY KEY (id)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;