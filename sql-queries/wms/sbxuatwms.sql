CREATE TABLE IF NOT EXISTS sbxuatwms.storage_dockdoor_position
(
    id UUID,
    whId Int8,
    dockdoorId UUID,
    x Float64,
    y Float64,
    createdAt DateTime64(3, 'UTC'),
    updatedAt DateTime64(3, 'UTC'),
    active Bool
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, dockdoorId);

CREATE TABLE IF NOT EXISTS sbxuatwms.storage_bin_dockdoor
(
    id UUID,
    whId Int8,
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
    code LowCardinality(String),
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
    code LowCardinality(String),
    description String,
    binTypeId UUID,
    zoneId UUID,
    binHuId UUID,
    multiSku Bool DEFAULT 1,
    createdAt DateTime64(3, 'UTC') DEFAULT now(),
    updatedAt DateTime64(3, 'UTC') DEFAULT now(),
    multiBatch Bool DEFAULT 1,
    pickingPosition Int32 DEFAULT 0,
    putawayPosition Int32 DEFAULT 0,
    status LowCardinality(String) DEFAULT 'ACTIVE',
    rank Int32 DEFAULT 1,
    aisle LowCardinality(String),
    bay LowCardinality(String),
    level LowCardinality(String),
    position LowCardinality(String),
    depth LowCardinality(String),
    maxSkuCount Int32,
    maxSkuBatchCount Int32,
    attrs Map(String, String) DEFAULT map()
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, code);


CREATE TABLE IF NOT EXISTS sbxuatwms.storage_bin_type
(
    id UUID,
    whId Int8,
    code LowCardinality(String),
    description String,
    maxVolumeInCC Float64,
    maxWeightInKG Float64,
    active Bool DEFAULT 1,
    createdAt DateTime64(3, 'UTC') DEFAULT now(),
    updatedAt DateTime64(3, 'UTC') DEFAULT now(),
    palletCapacity Int32,
    storageHUType LowCardinality(String) DEFAULT 'NONE',
    auxiliaryBin Bool DEFAULT 0,
    huMultiSku Bool DEFAULT 1,
    huMultiBatch Bool DEFAULT 1,
    useDerivedPalletBestFit Bool DEFAULT 1
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
    active Bool DEFAULT 1,
    createdAt DateTime64(3, 'UTC') DEFAULT now(),
    updatedAt DateTime64(3, 'UTC') DEFAULT now(),
    peripheral Bool DEFAULT 0,
    surveillanceConfig String
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, code);


CREATE TABLE IF NOT EXISTS sbxuatwms.storage_area_sloc
(
    whId Int8,
    id UUID,
    areaCode LowCardinality(String),
    quality LowCardinality(String),
    sloc LowCardinality(String),
    slocDescription String,
    clientQuality LowCardinality(String),
    createdAt DateTime64(3, 'UTC') DEFAULT now(),
    updatedAt DateTime64(3, 'UTC') DEFAULT now(),
    deactivatedAt DateTime64(3, 'UTC'),
    inventoryVisible Bool DEFAULT 1,
    erpToWMS Bool DEFAULT 1
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, areaCode, sloc);


CREATE TABLE IF NOT EXISTS sbxuatwms.storage_area
(
    id UUID,
    whId Int8,
    code LowCardinality(String),
    description String,
    type LowCardinality(String),
    active Bool DEFAULT 1,
    createdAt DateTime64(3, 'UTC') DEFAULT now(),
    updatedAt DateTime64(3, 'UTC') DEFAULT now(),
    rollingDays Int32
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, code);


CREATE TABLE IF NOT EXISTS sbxuatwms.storage_position
(
    id UUID,
    whId Int8,
    storageId UUID,
    x1 Float64,
    x2 Float64,
    y1 Float64,
    y2 Float64,
    createdAt DateTime64(3, 'UTC') DEFAULT now(),
    updatedAt DateTime64(3, 'UTC') DEFAULT now(),
    active Bool DEFAULT 1
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, storageId);
