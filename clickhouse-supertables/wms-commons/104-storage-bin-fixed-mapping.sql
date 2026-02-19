-- ClickHouse table for Storage Bin Fixed Mapping
-- Source: public.storage_bin_fixed_mapping

CREATE TABLE IF NOT EXISTS wms_storage_bin_fixed_mapping
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    binId String DEFAULT '',
    value String DEFAULT '',
    active Bool DEFAULT true,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    mode String DEFAULT 'SKU',
    PRIMARY KEY (id)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192
COMMENT 'Storage Bin Fixed Mapping table';