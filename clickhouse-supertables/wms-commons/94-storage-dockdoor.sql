-- ClickHouse table for Storage Dockdoor
-- Source: public.storage_dockdoor

CREATE TABLE IF NOT EXISTS wms_storage_dockdoor
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    code String DEFAULT '',
    description String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    maxQueue Int64 DEFAULT 0,
    allowInbound Bool DEFAULT false,
    allowOutbound Bool DEFAULT false,
    allowReturns Bool DEFAULT false,
    incompatibleVehicleTypes String DEFAULT '[]', -- Store JSON as String or use JSON type if supported
    status String DEFAULT '',
    incompatibleLoadTypes String DEFAULT '[]',    -- Store JSON as String or use JSON type if supported
    PRIMARY KEY (id)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;