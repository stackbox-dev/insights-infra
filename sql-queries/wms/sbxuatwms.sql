CREATE TABLE IF NOT EXISTS sbxuat.storage_dockdoor_position
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
ORDER BY (whId, dockdoorId, id);

CREATE TABLE IF NOT EXISTS sbxuat.storage_bin_dockdoor
(
    id UUID,
    whId Int64,
    binId UUID,
    dockdoorId UUID,
    active Bool,
    createdAt DateTime64(3, 'UTC'),
    updatedAt DateTime64(3, 'UTC'),
    usage LowCardinality(Nullable(String)),
    dockHandlingUnit LowCardinality(Nullable(String)),
    multiTrip Bool
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, binId, dockdoorId, id);

CREATE TABLE IF NOT EXISTS sbxuat.storage_dockdoor
(
    id UUID,
    whId Int64,
    code LowCardinality(String),
    description LowCardinality(String),
    createdAt DateTime64(3, 'UTC'),
    updatedAt DateTime64(3, 'UTC'),
    maxQueue Int64,
    allowInbound Bool,
    allowOutbound Bool,
    allowReturns Bool,
    incompatibleVehicleTypes LowCardinality(String),
    status LowCardinality(String),
    incompatibleLoadTypes LowCardinality(String)
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, code, id);

CREATE TABLE IF NOT EXISTS sbxuat.storage_bin
(
    id UUID,
    whId Int64,
    code LowCardinality(String),
    description LowCardinality(String),
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
    aisle LowCardinality(Nullable(String)),
    bay LowCardinality(Nullable(String)),
    level LowCardinality(Nullable(String)),
    position LowCardinality(Nullable(String)),
    depth LowCardinality(Nullable(String)),
    maxSkuCount Nullable(Int32),
    maxSkuBatchCount Nullable(Int32),
    attrs LowCardinality(String)
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, code, id);


CREATE TABLE IF NOT EXISTS sbxuat.storage_bin_type
(
    id UUID,
    whId Int64,
    code LowCardinality(String),
    description LowCardinality(String),
    maxVolumeInCC Float64,
    maxWeightInKG Float64,
    active Bool DEFAULT 1,
    createdAt DateTime64(3, 'UTC'),
    updatedAt DateTime64(3, 'UTC'),
    palletCapacity Nullable(Int32),
    storageHUType LowCardinality(String),
    auxiliaryBin Bool,
    huMultiSku Bool,
    huMultiBatch Bool,
    useDerivedPalletBestFit Bool
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, code, id);

CREATE TABLE IF NOT EXISTS sbxuat.storage_zone
(
    id UUID,
    whId Int64,
    code LowCardinality(String),
    description LowCardinality(String),
    face LowCardinality(String),
    areaId UUID,
    active Bool,
    createdAt DateTime64(3, 'UTC'),
    updatedAt DateTime64(3, 'UTC'),
    peripheral Bool,
    surveillanceConfig LowCardinality(Nullable(String))
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, code, id);


CREATE TABLE IF NOT EXISTS sbxuat.storage_area_sloc
(
    whId Int64,
    id UUID,
    areaCode LowCardinality(String),
    quality LowCardinality(String),
    sloc LowCardinality(String),
    slocDescription LowCardinality(String),
    clientQuality LowCardinality(String),
    createdAt DateTime64(3, 'UTC'),
    updatedAt DateTime64(3, 'UTC'),
    deactivatedAt Nullable(DateTime64(3, 'UTC')),
    inventoryVisible Bool,
    erpToWMS Bool
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, areaCode, sloc, id);


CREATE TABLE IF NOT EXISTS sbxuat.storage_area
(
    id UUID,
    whId Int64,
    code LowCardinality(String),
    description LowCardinality(String),
    type LowCardinality(String),
    active Bool,
    createdAt DateTime64(3, 'UTC'),
    updatedAt DateTime64(3, 'UTC'),
    rollingDays Nullable(Int32)
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, code, id);


CREATE TABLE IF NOT EXISTS sbxuat.storage_position
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
ORDER BY (whId, storageId, id);
