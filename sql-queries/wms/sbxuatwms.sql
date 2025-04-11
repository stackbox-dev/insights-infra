CREATE TABLE IF NOT EXISTS sbxuatwms.storage_dockdoor_position
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
ORDER BY (id);

CREATE TABLE IF NOT EXISTS sbxuatwms.storage_bin_dockdoor
(
    id UUID,
    whId Int64,
    binId UUID,
    dockdoorId UUID,
    active Bool,
    createdAt DateTime64(3, 'UTC'),
    updatedAt DateTime64(3, 'UTC'),
    usage LowCardinality(String),
    dockHandlingUnit String,
    multiTrip Bool
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, binId, dockdoorId);

CREATE TABLE IF NOT EXISTS sbxuatwms.storage_dockdoor
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
    incompatibleVehicleTypes Array(String),
    status LowCardinality(String),
    incompatibleLoadTypes Array(String)
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, code);

CREATE TABLE IF NOT EXISTS sbxuatwms.storage_bin
(
    id UUID,
    whId Int8,
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
    aisle String,
    bay String,
    level String,
    position String,
    depth String,
    maxSkuCount Int32,
    maxSkuBatchCount Int32,
    attrs JSON
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id);


CREATE TABLE IF NOT EXISTS sbxuatwms.storage_bin_type
(
    id UUID,
    whId Int8,
    code LowCardinality(String),
    description String,
    maxVolumeInCC Float64,
    maxWeightInKG Float64,
    active Bool,
    createdAt DateTime64(3, 'UTC'),
    updatedAt DateTime64(3, 'UTC'),
    palletCapacity Int32,
    storageHUType LowCardinality(String) DEFAULT 'NONE',
    auxiliaryBin Bool,
    huMultiSku Bool,
    huMultiBatch Bool,
    useDerivedPalletBestFit Bool
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, code);

CREATE TABLE IF NOT EXISTS sbxuatwms.storage_zone
(
    id UUID,
    whId Int8,
    code LowCardinality(String),
    description String,
    face LowCardinality(String),
    areaId UUID,
    active Bool,
    createdAt DateTime64(3, 'UTC'),
    updatedAt DateTime64(3, 'UTC'),
    peripheral Bool,
    surveillanceConfig String
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id);


CREATE TABLE IF NOT EXISTS sbxuatwms.storage_area_sloc
(
    whId Int8,
    id UUID,
    areaCode LowCardinality(String),
    quality LowCardinality(String),
    sloc LowCardinality(String),
    slocDescription String,
    clientQuality LowCardinality(String),
    createdAt DateTime64(3, 'UTC'),
    updatedAt DateTime64(3, 'UTC'),
    deactivatedAt DateTime64(3, 'UTC'),
    inventoryVisible Bool,
    erpToWMS Bool
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, areaCode, quality);


CREATE TABLE IF NOT EXISTS sbxuatwms.storage_area
(
    id UUID,
    whId Int8,
    code LowCardinality(String),
    description String,
    type LowCardinality(String),
    active Bool,
    createdAt DateTime64(3, 'UTC'),
    updatedAt DateTime64(3, 'UTC'),
    rollingDays Int32
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id);

CREATE TABLE IF NOT EXISTS sbxuatwms.storage_position
(
    id UUID,
    whId Int8,
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
