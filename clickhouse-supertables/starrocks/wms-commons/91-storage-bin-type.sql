CREATE TABLE wms_storage_bin_type (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    code STRING NOT NULL,
    description STRING,
    maxVolumeInCC DOUBLE,
    maxWeightInKG DOUBLE,
    active BOOLEAN NOT NULL DEFAULT "true",
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    palletCapacity INT,
    storageHUType STRING NOT NULL DEFAULT 'NONE',
    auxiliaryBin BOOLEAN NOT NULL DEFAULT "false",
    huMultiSku BOOLEAN NOT NULL DEFAULT "true",
    huMultiBatch BOOLEAN NOT NULL DEFAULT "true",
    useDerivedPalletBestFit BOOLEAN NOT NULL DEFAULT "true",
    onlyFullPallet BOOLEAN NOT NULL DEFAULT "false",
    fullPalletPickThreshold DOUBLE
)
ENGINE=OLAP
PRIMARY KEY(id, createdAt)
DISTRIBUTED BY HASH(id)
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
