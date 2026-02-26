-- ClickHouse table for Storage Bin Dockdoor
-- Source: public.storage_bin_dockdoor

CREATE TABLE IF NOT EXISTS wms_storage_bin_dockdoor
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    binId String DEFAULT '',
    dockdoorId String DEFAULT '',
    active Bool DEFAULT true,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    usage String DEFAULT '',
    dockHandlingUnit String DEFAULT '',
    multiTrip Bool DEFAULT false,
    PRIMARY KEY (id)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;