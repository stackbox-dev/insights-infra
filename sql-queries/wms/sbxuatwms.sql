CREATE TABLE IF NOT EXISTS sbx_uat_wms.storage_dockdoor_position
(
    id UUID,
    whId Int64,
    dockdoorId UUID,
    x Float64,
    y Float64,
    createdAt DateTime64(3, 'UTC'),
    updatedAt DateTime64(3, 'UTC'),
    active Bool
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (dockdoorId);

CREATE TABLE IF NOT EXISTS sbx_uat_wms.storage_bin_dockdoor
(
    id UUID,
    whId Int64,
    binId UUID,
    dockdoorId UUID,
    active Bool,
    createdAt DateTime64(3, 'UTC'),
    updatedAt DateTime64(3, 'UTC'),
    usage LowCardinality(String) DEFAULT 0,
    dockHandlingUnit String DEFAULT 0,
    multiTrip Bool
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, binId, dockdoorId);

CREATE TABLE IF NOT EXISTS sbx_uat_wms.storage_dockdoor
(
    id UUID,
    whId Int64,
    code String,
    description String,
    createdAt DateTime64(3, 'UTC'),
    updatedAt DateTime64(3, 'UTC'),
    maxQueue Int64,
    allowInbound Bool,
    allowOutbound Bool,
    allowReturns Bool,
    incompatibleVehicleTypes String,
    status LowCardinality(String),
    incompatibleLoadTypes String
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, code);

CREATE TABLE IF NOT EXISTS sbx_uat_wms.storage_bin
(
    id UUID,
    whId Int64,
    code String,
    description String,
    binTypeId UUID,
    zoneId UUID,
    binHuId UUID,
    multiSku Bool,
    createdAt DateTime64(3, 'UTC'),
    updatedAt DateTime64(3, 'UTC'),
    multiBatch Bool,
    pickingPosition Int32,
    putawayPosition Int32,
    status LowCardinality(String),
    rank Int32,
    aisle String DEFAULT 0,
    bay String DEFAULT 0,
    level String DEFAULT 0,
    position String DEFAULT 0,
    depth String DEFAULT 0,
    maxSkuCount Int32 DEFAULT 0,
    maxSkuBatchCount Int32 DEFAULT 0,
    attrs String
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, code);


CREATE TABLE IF NOT EXISTS sbx_uat_wms.storage_bin_type
(
    id UUID,
    whId Int64,
    code LowCardinality(String),
    description String,
    maxVolumeInCC Float64,
    maxWeightInKG Float64,
    active Bool,
    createdAt DateTime64(3, 'UTC'),
    updatedAt DateTime64(3, 'UTC'),
    palletCapacity Int32 DEFAULT 0,
    storageHUType LowCardinality(String) DEFAULT 'NONE',
    auxiliaryBin Bool,
    huMultiSku Bool,
    huMultiBatch Bool,
    useDerivedPalletBestFit Bool
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, code);

CREATE TABLE IF NOT EXISTS sbx_uat_wms.storage_zone
(
    id UUID,
    whId Int64,
    code LowCardinality(String),
    description String,
    face LowCardinality(String),
    areaId UUID,
    active Bool,
    createdAt DateTime64(3, 'UTC'),
    updatedAt DateTime64(3, 'UTC'),
    peripheral Bool,
    surveillanceConfig String DEFAULT 0
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, code);

CREATE TABLE IF NOT EXISTS sbx_uat_wms.storage_area_sloc
(
    whId Int64,
    id UUID,
    areaCode LowCardinality(String),
    quality LowCardinality(String),
    sloc LowCardinality(String),
    slocDescription String,
    clientQuality LowCardinality(String),
    createdAt DateTime64(3, 'UTC'),
    updatedAt DateTime64(3, 'UTC'),
    deactivatedAt DateTime64(3, 'UTC') DEFAULT 0,
    inventoryVisible Bool,
    erpToWMS Bool
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, areaCode, quality);


CREATE TABLE IF NOT EXISTS sbx_uat_wms.storage_area
(
    id UUID,
    whId Int64,
    code LowCardinality(String),
    description String,
    type LowCardinality(String),
    active Bool,
    createdAt DateTime64(3, 'UTC'),
    updatedAt DateTime64(3, 'UTC'),
    rollingDays Int32 DEFAULT 0,
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, code);

CREATE TABLE IF NOT EXISTS sbx_uat_wms.storage_position
(
    id UUID,
    whId Int64,
    storageId UUID,
    x1 Float64,
    x2 Float64,
    y1 Float64,
    y2 Float64,
    createdAt DateTime64(3, 'UTC'),
    updatedAt DateTime64(3, 'UTC'),
    active Bool
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (storageId);
