
-- ClickHouse table for Storage Bin
-- Source: public.storage_bin

CREATE TABLE IF NOT EXISTS wms_storage_bin
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    code String DEFAULT '',
    description String DEFAULT '',
    binTypeId String DEFAULT '',
    zoneId String DEFAULT '',
    binHuId String DEFAULT '',
    multiSku Bool DEFAULT true,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    multiBatch Bool DEFAULT true,
    pickingPosition Int32 DEFAULT 0,
    putawayPosition Int32 DEFAULT 0,
    status String DEFAULT 'ACTIVE',
    rank Int32 DEFAULT 1,
    aisle String DEFAULT '',
    bay String DEFAULT '',
    level String DEFAULT '',
    position String DEFAULT '',
    depth String DEFAULT '',
    maxSkuCount Int32 DEFAULT 0,
    maxSkuBatchCount Int32 DEFAULT 0,
    attrs String DEFAULT '{}', -- Store JSON as String or use JSON type if supported
    PRIMARY KEY (id)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;