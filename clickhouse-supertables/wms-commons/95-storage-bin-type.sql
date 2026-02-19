-- ClickHouse table for Storage Bin Type
-- Source: public.storage_bin_type

CREATE TABLE IF NOT EXISTS wms_storage_bin_type
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    code String DEFAULT '',
    description String DEFAULT '',
    maxVolumeInCC Float64 DEFAULT 0.0,
    maxWeightInKG Float64 DEFAULT 0.0,
    active Bool DEFAULT true,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    palletCapacity Int32 DEFAULT 0,
    storageHUType String DEFAULT 'NONE',
    auxiliaryBin Bool DEFAULT false,
    huMultiSku Bool DEFAULT true,
    huMultiBatch Bool DEFAULT true,
    useDerivedPalletBestFit Bool DEFAULT true,
    onlyFullPallet Bool DEFAULT false,
    fullPalletPickThreshold Float64 DEFAULT 0.0,
    PRIMARY KEY (id)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;