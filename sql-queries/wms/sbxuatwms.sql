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
ORDER BY (id);

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
ORDER BY (id);

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
ORDER BY (id);

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
ORDER BY (id);


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
ORDER BY (id);

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
ORDER BY (id);

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
ORDER BY (id);


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
ORDER BY (id);

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
ORDER BY (id);

CREATE TABLE IF NOT EXISTS sbx_uat_wms.inventory 
(
    "whId" Int64,
    "id" UUID,
    "huId" String,
    "huCode" String,
    "huKind" String,
    "huWeight" Float64 DEFAULT 0,
    "huOnHold" Bool,
    "huRendered" Bool,
    "huLockTaskId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "isBinHu" Bool,
    "areaType" String DEFAULT 0,
    "areaCode" String DEFAULT 0,
    "zoneFace" String DEFAULT 0,
    "zoneCode" String DEFAULT 0,
    "binType" String DEFAULT 0,
    "binCode" String DEFAULT 0,
    "binStatus" String DEFAULT 0,
    "binCapacity" Int32 DEFAULT 0,
    "outerHUCode" String DEFAULT 0,
    "outerHUKind" String DEFAULT 0,
    "skuId" String,
    "skuCode" String,
    "skuName" String,
    "skuInventoryType" String,
    "productCode" String,
    "category" String,
    "categoryGroup" String,
    "skuClassification" String,
    "plantCode" String DEFAULT 0,
    "brand" String,
    "bucket" String,
    "inclusionStatus" String,
    "uom" String,
    "batch" String DEFAULT 0,
    "manufactureDate" Date DEFAULT toDate('1970-01-01'),
    "expiryDate" Date DEFAULT toDate('1970-01-01'),
    "price" String DEFAULT 0,
    "quantLockMode" String,
    "qty" Int32 NOT NULL,
    "qtyL0" Int64,
    "huUpdatedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "quantUpdatedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "updatedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "binTypeId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "usage" Float64 DEFAULT 0,
    "huCountBlocked" bool DEFAULT false,
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id);

CREATE TABLE IF NOT EXISTS sbx_uat_wms.storage_bin_fixed_mapping (
    "id" UUID,
    "whId" Int64,
    "binId" UUID,
    "value" String,
    "active" Bool,
    "createdAt" DateTime64(3, 'UTC') DEFAULT 0,
    "updatedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "mode" String,
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id);

CREATE TABLE IF NOT EXISTS sbx_uat_wms.pd_drop_item
(
    "id" UUID,
    "whId" Int64,
    "sessionId" UUID,
    "taskId" UUID,
    "sourceBinId" UUID,
    "sourceBinHUId" UUID,
    "sourceBinCode" String,
    "skuId" UUID,
    "batch" String,
    "uom" String,
    "bucket" String,
    "qty" Int32,
    "huId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "huCode" String DEFAULT 0,
    "binId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "binHUId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "binCode" String DEFAULT 0,
    "createdAt" DateTime64(3, 'UTC'),
    "deactivatedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "deactivatedBy" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "droppedQty" Int32 DEFAULT 0,
    "droppedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "droppedBy" String DEFAULT 0,
    "updatedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "dropHUInBin" Bool DEFAULT True,
    "scanDestHU" Bool DEFAULT False,
    "allowHUBreak" Bool DEFAULT False,
    "hasInnerHUs" Bool DEFAULT False,
    "scanInnerHUs" Bool DEFAULT False,
    "huEqUOM" String DEFAULT 0,
    "destHUId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "destHUCode" String DEFAULT 0,
    "droppedInnerHUId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "innerHUEqUOM" String DEFAULT 0,
    "binAssignedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "dropUOM" String DEFAULT 0,
    "eligibleDropLocations" String,
    "parentItemId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "huBroken" Bool DEFAULT False,
    "pickedBy" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "sourceBucket" String DEFAULT 0,
    "originalDestinationBinId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "originalDestinationBinCode" String DEFAULT 0,
    "lmTripId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "processedForLoadingAt" DateTime64(3, 'UTC') DEFAULT 0,
    "quantBucket" String DEFAULT 0,
    "innerHUId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "innerHUCode" String DEFAULT 0,
    "innerHUKindId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "innerHUKindCode" String DEFAULT 0,
    "dropInnerHU" Bool DEFAULT true,
    "allowInnerHUBreak" Bool DEFAULT false,
    "innerHUBroken" Bool DEFAULT false,
    "autoCompleted" Bool DEFAULT false,
    "processedForPickAt" DateTime64(3, 'UTC') DEFAULT 0,
    "quantSlottingForHUs" Bool DEFAULT false,
    "pdPreviousTaskId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "processedOnDropAt" DateTime64(3, 'UTC') DEFAULT 0,
    "provisionalItemId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "allowHUBreakV2" Bool DEFAULT True,
    "inputDestHUId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "legIndex" Int32  DEFAULT 0,
    "lastLeg" Bool DEFAULT False,
    "inputDestBinId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id);

CREATE TABLE IF NOT EXISTS sbx_uat_wms.task 
(
    "whId" Int64,
    "id" UUID,
    "sessionId" UUID,
    "kind" String,
    "code" String,
    "seq" Int32,
    "exclusive" Bool,
    "state" String,
    "attrs" String,
    "progress" String,
    "createdAt" DateTime64(3, 'UTC'),
    "updatedAt" DateTime64(3, 'UTC'),
    "active" Bool DEFAULT true,
    "allowForceComplete" Bool DEFAULT true,
    "autoComplete" Bool DEFAULT false,
    "wave" Int32 DEFAULT 0,
    "forceCompleteTaskId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "forceCompleted" Bool DEFAULT false,
    "subKind" String DEFAULT 0,
    "label" String DEFAULT 0
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id);

CREATE TABLE IF NOT EXISTS sbx_uat_wms.handling_unit 
(
    "whId" Int64,
    "id" UUID,
    "code" String,
    "kindId" UUID,
    "sessionId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "taskId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "storageId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "outerHuId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "state" String,
    "attrs" String,
    "createdAt" DateTime64(3, 'UTC'),
    "updatedAt" DateTime64(3, 'UTC'),
    "lockTaskId" UUID DEFAULT '00000000-0000-0000-0000-000000000000'
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id);

CREATE TABLE IF NOT EXISTS sbx_uat_wms.worker 
(
    "whId" Int64,
    "id" UUID,
    "code" String,
    "name" String,
    "phone" String,
    "attrs" String,
    "images" String,
    "active" Bool DEFAULT true,
    "createdAt" DateTime64(3, 'UTC'),
    "updatedAt" DateTime64(3, 'UTC'),
    "supervisor" Bool DEFAULT false,
    "quantIdentifiers" String,
    "mheKindIds" String DEFAULT 0,
    "eligibleZones" String DEFAULT 0
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id);

CREATE TABLE IF NOT EXISTS sbx_uat_wms.session
(
    "whId" Int64,
    "id" UUID,
    "kind" String,
    "code" String,
    "attrs" String,
    "createdAt" DateTime64(3, 'UTC'),
    "updatedAt" DateTime64(3, 'UTC'),
    "active" Bool DEFAULT true,
    "state" String,
    "progress" String,
    "autoComplete" Bool DEFAULT true
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id);


CREATE TABLE IF NOT EXISTS sbx_uat_wms.pd_pick_item
(
    "id" UUID,
    "whId" Int64,
    "sessionId" UUID,
    "taskId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "binId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "binHUId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "binCode" String DEFAULT 0,
    "skuId" UUID,
    "batch" String,
    "uom" String,
    "bucket" String,
    "overallQty" Int32,
    "qty" Int32,
    "huId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "huCode" String DEFAULT 0,
    "destinationBinId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "destinationBinHUId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "destinationBinCode" String DEFAULT 0,
    "createdAt" DateTime64(3, 'UTC'),
    "deactivatedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "deactivatedBy" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "pickedQty" Int32 DEFAULT 0,
    "pickedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "pickedBy" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "movedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "movedBy" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "processedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "huEqUOM" String DEFAULT 0,
    "hasInnerHUs" Bool DEFAULT True,
    "innerHUEqUOM" String DEFAULT 0,
    "binAssignedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "scanSourceHUKind" String DEFAULT 0,
    "pickSourceHUKind" String DEFAULT 0,
    "carrierHUKind" String,
    "scannedSourceHUId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "scannedSourceHUCode" String DEFAULT 0,
    "pickedSourceHUId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "pickedSourceHUCode" String DEFAULT 0,
    "carrierHUId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "carrierHUCode" String DEFAULT 0,
    "huKind" String,
    "sourceHUEqUOM" String DEFAULT 0,
    "updatedAt" DateTime64(3, 'UTC'),
    "eligibleDropLocations" String,
    "parentItemId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "oldBatch" String DEFAULT 0,
    "destBucket" String DEFAULT 0,
    "originalSourceBinId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "originalSourceBinCode" String DEFAULT 0,
    "lmTripId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "innerHUId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "innerHUCode" String DEFAULT 0,
    "innerHUKindId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "innerHUKindCode" String DEFAULT 0,
    "quantBucket" String DEFAULT 0,
    "autoCompleted" Bool DEFAULT false,
    "pickHU" Bool DEFAULT true,
    "shortAllocationReason" String DEFAULT 0,
    "pdPreviousTaskId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "inputSourceBinId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "provisionalItemId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "inputDestHUId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "kind" String,
    "tpAssignedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "legIndex" Int32 DEFAULT 0,
    "lastLeg" Bool DEFAULT false,
    "epAssignedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "carrierHUFormedId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "huIndex" Int32 DEFAULT 0,
    "sequence" Int32 DEFAULT 0,
    "carrierHUForceClosed" Bool DEFAULT false,
    "inputDestBinId" UUID DEFAULT '00000000-0000-0000-0000-000000000000'
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id);

CREATE TABLE IF NOT EXISTS sbx_uat_wms.pd_pick_drop_mapping (
    "id" UUID,
    "whId" Int64,
    "sessionId" UUID,
    "taskId" UUID,
    "pickItemId" UUID,
    "dropItemId" UUID,
    "createdAt" DateTime64(3, 'UTC')
)
ENGINE = ReplacingMergeTree(createdAt)
ORDER BY (id);

CREATE TABLE IF NOT EXISTS sbx_uat_wms.trip
(
    sessionCreatedAt DateTime64(3, 'UTC'),
    whId Int64,
    sessionId UUID,
    id UUID,
    createdAt DateTime64(3, 'UTC'),
    bbId String DEFAULT 0,
    code String DEFAULT 0,
    "type" LowCardinality(String),
    "priority" Int32,
    dockdoorId UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    dockdoorCode LowCardinality(String) DEFAULT 0,
    vehicleId String DEFAULT 0,
    vehicleNo String DEFAULT 0,
    vehicleType String DEFAULT 0,
    deliveryDate Date DEFAULT toDate('1970-01-01')
)
ENGINE = ReplacingMergeTree(sessionCreatedAt)
ORDER BY (id);

CREATE TABLE IF NOT EXISTS sbx_uat_wms.trip_relation
(
    whId Int64,
    id UUID,
    sessionId UUID,
    xdock String,
    parentTripId UUID,
    childTripId UUID,
)
ENGINE = ReplacingMergeTree()
ORDER BY (id);

CREATE TABLE IF NOT EXISTS sbx_uat_wms.inb_receive_item (
    "whId" Int64,
    "sessionId" UUID,
    "taskId" UUID,
    "id" UUID,
    "skuId" UUID,
    "uom" String DEFAULT 0,
    "batch" String DEFAULT 0,
    "price" String DEFAULT 0,
    "overallQty" Int32,
    "qty" Int32,
    "parentItemId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "createdAt" DateTime64(3, 'UTC'),
    "asnVehicleId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "stagingBinId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "stagingBinHUId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "groupId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "receivedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "receivedBy" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "receivedQty" Int32 DEFAULT 0,
    "damagedQty" Int32 DEFAULT 0,
    "deactivatedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "qcPercentage" Int32 DEFAULT 0,
    "huId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "huCode" String DEFAULT 0,
    "reason" String DEFAULT 0,
    "bucket" String DEFAULT 0,
    "movedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "movedBy" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "processedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "huKind" String DEFAULT 0,
    "receivedHuKind" String DEFAULT 0,
    "totalHuWeight" Float64 DEFAULT 0,
    "receivedHuWeight" Float64 DEFAULT 0,
    "subReason" String DEFAULT 0
)
ENGINE = ReplacingMergeTree(createdAt)
ORDER BY (id);


CREATE TABLE IF NOT EXISTS sbx_uat_wms.ob_load_item (
    "whId" Int64,
    "id" UUID,
    "sessionId" UUID,
    "taskId" UUID,
    "tripId" UUID,
    "skuId" UUID,
    "skuClass" String DEFAULT 0,
    "uom" String DEFAULT 0,
    "qty" Int32,
    "seq" Int64,
    "loadedQty" Int32 DEFAULT 0,
    "loadedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "loadedBy" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "createdAt" DateTime64(3, 'UTC'),
    "invoiceId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "skuCategory" String DEFAULT 0,
    "originalSkuId" UUID,
    "batch" String,
    "huId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "huCode" String DEFAULT 0,
    "mmTripId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "innerHUId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "innerHUCode" String DEFAULT 0,
    "innerHUKind" String DEFAULT 0,
    "binId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "binHUId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "binCode" String DEFAULT 0,
    "parentItemId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "classificationType" String DEFAULT 0,
    "originalQty" Int32 DEFAULT 0,
    "originalUOM" String DEFAULT 0,
    "repicked" bool DEFAULT false,
    "invoiceCode" String DEFAULT 0,
    "retailerId" String DEFAULT 0,
    "retailerCode" String DEFAULT 0
)
ENGINE = ReplacingMergeTree(createdAt)
ORDER BY (id);

CREATE TABLE IF NOT EXISTS sbx_uat_wms.inb_palletization_item (
    "id" UUID,
    "whId" Int64,
    "sessionId" UUID,
    "taskId" UUID,
    "skuId" UUID,
    "batch" String DEFAULT 0,
    "price" String DEFAULT 0,
    "uom" String DEFAULT 0,
    "bucket" String DEFAULT 0,
    "qty" Int32,
    "huId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "huCode" String DEFAULT 0,
    "outerHUId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "outerHUCode" String DEFAULT 0,
    "serializationItemId" UUID,
    "createdAt" DateTime64(3, 'UTC'),
    "updatedAt" DateTime64(3, 'UTC'),
    "mappedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "mappedBy" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "reason" String DEFAULT 0,
    "stagingBinId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "stagingBinHuId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "asnId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "asnNo" String DEFAULT 0,
    "initialBucket" String,
    "qtyInside" Int32 DEFAULT 0,
    "uomInside" String DEFAULT 0,
    "subReason" String DEFAULT 0,
    "deactivatedAt" DateTime64(3, 'UTC') DEFAULT 0
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id);

CREATE TABLE IF NOT EXISTS sbx_uat_wms.inb_serialization_item (
    "id" UUID,
    "whId" Int64,
    "sessionId" UUID,
    "taskId" UUID,
    "skuId" UUID,
    "batch" String DEFAULT 0,
    "uom" String DEFAULT 0,
    "qty" Int32,
    "huId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "huCode" String DEFAULT 0,
    "createdAt" DateTime64(3, 'UTC'),
    "serializedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "serializedBy" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "bucket" String,
    "stagingBinId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "stagingBinHuId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "qtyInside" Int32 DEFAULT 0,
    "printLabel" String DEFAULT 0,
    "preparedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "preparedBy" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "uomInside" String DEFAULT 0,
    "reason" String DEFAULT 0,
    "subReason" String DEFAULT 0,
    "reasonUpdatedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "reasonUpdatedBy" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "mode" String DEFAULT 0,
    "rejected" bool DEFAULT false,
    "deactivatedAt" DateTime64(3, 'UTC') DEFAULT 0
)
ENGINE = ReplacingMergeTree(createdAt)
ORDER BY (id);


CREATE TABLE IF NOT EXISTS sbx_uat_wms.inb_qc_item_v2 (
    "id" UUID,
    "whId" Int64,
    "sessionId" UUID,
    "taskId" UUID,
    "skuId" UUID,
    "uom" String DEFAULT 0,
    "batch" String DEFAULT 0,
    "bucket" String DEFAULT 0,
    "price" String DEFAULT 0,
    "qty" Int32,
    "receivedQty" Int32,
    "sampleSize" Int32 DEFAULT 0,
    "inspectionLevel" String DEFAULT 0,
    "acceptableIssueSize" Int32 DEFAULT 0,
    "actualSkuId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "actualUom" String DEFAULT 0,
    "actualBatch" String DEFAULT 0,
    "actualPrice" String DEFAULT 0,
    "actualBucket" String DEFAULT 0,
    "actualQty" Int32 DEFAULT 0,
    "actualQtyInside" Int32 DEFAULT 0,
    "parentItemId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "createdAt" DateTime64(3, 'UTC'),
    "createdBy" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "deactivatedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "deactivatedBy" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "updatedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "movedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "movedBy" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "movedQty" Int32 DEFAULT 0,
    "processedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "uomInside" String DEFAULT 0,
    "reason" String DEFAULT 0,
    "subReason" String DEFAULT 0,
    "batchOverridden" String DEFAULT 0
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id);


CREATE TABLE IF NOT EXISTS sbx_uat_wms.ira_bin_items (
    "id" UUID,
    "whId" Int64,
    "sessionId" UUID,
    "taskId" UUID,
    "binId" UUID,
    "skuId" UUID,
    "uom" String DEFAULT 0,
    "systemQty" Int32 DEFAULT 0,
    "systemDamagedQty" Int32 DEFAULT 0,
    "physicalQty" Int32 DEFAULT 0,
    "physicalDamagedQty" Int32 DEFAULT 0,
    "finalQty" Int32 DEFAULT 0,
    "finalDamagedQty" Int32 DEFAULT 0,
    "issue" String DEFAULT 0,
    "state" String DEFAULT 0,
    "createdAt" DateTime64(3, 'UTC'),
    "scannedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "scannedBy" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "approvedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "approvedBy" String DEFAULT 0,
    "batch" String,
    "processedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "sourceHUId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "sourceHUCode" String DEFAULT 0,
    "transactionId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "binStorageHUType" String DEFAULT 0,
    "deactivatedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "updatedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "updatedBy" String DEFAULT 0,
    "huSameBinBeforeIRA" String,
    "recordNo" Int32 DEFAULT 1,
    "hlrStatus" String DEFAULT 0
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id);

CREATE TABLE IF NOT EXISTS sbx_uat_wms.ob_qa_lineitem (
    "id" UUID,
    "whId" Int64,
    "sessionId" UUID,
    "taskId" UUID,
    "invoiceId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "invoiceCode" String DEFAULT 0,
    "skuId" UUID,
    "skuClass" String DEFAULT 0,
    "skuCategory" String DEFAULT 0,
    "uom" String DEFAULT 0,
    "orderedQty" Int32 DEFAULT 0,
    "pickedQty" Int32 DEFAULT 0,
    "packedQty" Int32 DEFAULT 0,
    "createdAt" DateTime64(3, 'UTC'),
    "updatedAt" DateTime64(3, 'UTC') DEFAULT 0,
    "updatedBy" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "tripId" UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    "tripCode" String DEFAULT 0,
    "batch" String,
    "retailerId" String DEFAULT 0,
    "retailerCode" String DEFAULT 0
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id);