-- Migration: Add PARTITION BY to all wms-commons fact tables
-- Run this to drop and recreate all 24 fact tables with partitioning.
-- WARNING: This will delete all data in these tables. Re-ingest from source after running.
-- Generated: 2026-03-23

-- ============================================================
-- 04: wms_sessions
-- ============================================================
DROP TABLE IF EXISTS wms_sessions;
CREATE TABLE IF NOT EXISTS wms_sessions
(
    whId Int64 DEFAULT 0,
    id String,
    kind String DEFAULT '',
    code String DEFAULT '',
    attrs String DEFAULT '{}',  -- JSON
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    active Bool DEFAULT false,
    state String DEFAULT '',
    progress String DEFAULT '{}',  -- JSON
    autoComplete Bool DEFAULT false,

    -- Indexes for common query patterns
    INDEX idx_whId whId TYPE minmax GRANULARITY 1,
    INDEX idx_code code TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_kind kind TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_active active TYPE minmax GRANULARITY 1,
    INDEX idx_state state TYPE bloom_filter(0.01) GRANULARITY 1
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)  -- id is globally unique
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop',
         min_age_to_force_merge_seconds = 180
COMMENT 'WMS Sessions dimension table';

-- ============================================================
-- 05: wms_tasks
-- ============================================================
DROP TABLE IF EXISTS wms_tasks;
CREATE TABLE IF NOT EXISTS wms_tasks
(
    whId Int64 DEFAULT 0,
    id String,
    sessionId String DEFAULT '',
    kind String DEFAULT '',
    code String DEFAULT '',
    seq Int32 DEFAULT 0,
    exclusive Bool DEFAULT false,
    state String DEFAULT '',
    attrs String DEFAULT '{}',  -- JSON
    progress String DEFAULT '{}',  -- JSON
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    active Bool DEFAULT false,
    allowForceComplete Bool DEFAULT false,
    autoComplete Bool DEFAULT false,
    wave Int32 DEFAULT 0,
    forceCompleteTaskId String DEFAULT '',
    forceCompleted Bool DEFAULT false,
    subKind String DEFAULT '',
    label String DEFAULT '',

    -- Indexes for common query patterns
    INDEX idx_whId whId TYPE minmax GRANULARITY 1,
    INDEX idx_sessionId sessionId TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_code code TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_kind kind TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_state state TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_active active TYPE minmax GRANULARITY 1,
    INDEX idx_wave wave TYPE minmax GRANULARITY 1
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)  -- id is globally unique
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop',
         min_age_to_force_merge_seconds = 180
COMMENT 'WMS Tasks dimension table';

-- ============================================================
-- 06: wms_trips
-- ============================================================
DROP TABLE IF EXISTS wms_trips;
CREATE TABLE IF NOT EXISTS wms_trips
(
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    whId Int64 DEFAULT 0,
    sessionId String DEFAULT '',
    id String,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    bbId String DEFAULT '',
    code String DEFAULT '',
    type String DEFAULT '',
    priority Int32 DEFAULT 0,
    dockdoorId String DEFAULT '',
    dockdoorCode String DEFAULT '',
    vehicleId String DEFAULT '',
    vehicleNo String DEFAULT '',
    vehicleType String DEFAULT '',
    deliveryDate Date DEFAULT toDate('1970-01-01'),

    -- Indexes for common query patterns
    INDEX idx_whId whId TYPE minmax GRANULARITY 1,
    INDEX idx_sessionId sessionId TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_code code TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_type type TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_deliveryDate deliveryDate TYPE minmax GRANULARITY 1
)
ENGINE = ReplacingMergeTree(createdAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)  -- id is globally unique
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop',
         min_age_to_force_merge_seconds = 180
COMMENT 'WMS Trips dimension table';

-- ============================================================
-- 07: wms_trip_relations
-- ============================================================
DROP TABLE IF EXISTS wms_trip_relations;
CREATE TABLE IF NOT EXISTS wms_trip_relations
(
    whId Int64 DEFAULT 0,
    id String,  -- UUID, globally unique primary key
    sessionId String DEFAULT '',
    xdock String DEFAULT '',
    parentTripId String DEFAULT '',
    childTripId String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),

    -- Indexes for common query patterns
    INDEX idx_whId whId TYPE minmax GRANULARITY 1,
    INDEX idx_sessionId sessionId TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_parentTripId parentTripId TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_childTripId childTripId TYPE bloom_filter(0.01) GRANULARITY 1
)
ENGINE = ReplacingMergeTree(createdAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)  -- id is the unique identifier from source
SETTINGS index_granularity = 8192,
         min_age_to_force_merge_seconds = 180
COMMENT 'WMS Trip Relations dimension table';

-- ============================================================
-- 08: wms_inb_asn
-- ============================================================
DROP TABLE IF EXISTS wms_inb_asn;
CREATE TABLE IF NOT EXISTS wms_inb_asn
(
    id String,
    whId Int64 DEFAULT 0,
    asnNo String DEFAULT '',
    sessionId String DEFAULT '',
    active Bool DEFAULT true,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    shipmentDate Date DEFAULT toDate('1970-01-01'),
    deliveryNo String DEFAULT '',
    priority Int32 DEFAULT 0,
    asnType String DEFAULT ''
)
ENGINE = ReplacingMergeTree(createdAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;

-- ============================================================
-- 09: wms_inb_asn_lineitem
-- ============================================================
DROP TABLE IF EXISTS wms_inb_asn_lineitem;
CREATE TABLE IF NOT EXISTS wms_inb_asn_lineitem
(
    id String,
    whId Int64 DEFAULT 0,
    asnId String,
    asnNo String DEFAULT '',
    vehicleNo String DEFAULT '',
    poNo String DEFAULT '',
    shipmentDate Date DEFAULT toDate('1970-01-01'),
    skuId String,
    uom String DEFAULT '',
    batch String DEFAULT '',
    price String DEFAULT '',
    qty Int32 DEFAULT 0,
    vendor String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    deliveryNo String DEFAULT '',
    priority Int32 DEFAULT 0,
    lineCode String DEFAULT '',
    extraFields String DEFAULT '{}',
    bucket String DEFAULT '',
    active Bool DEFAULT true,
    asnType String DEFAULT '',
    huWeight Float64 DEFAULT 0.0,
    huNumber String DEFAULT '',
    huKind String DEFAULT '',
    huCode String DEFAULT '',
    vehicleType String DEFAULT '',
    transporterCode String DEFAULT ''
)
ENGINE = ReplacingMergeTree(createdAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;

-- ============================================================
-- 10: wms_po_oms_allocation
-- ============================================================
DROP TABLE IF EXISTS wms_po_oms_allocation;
CREATE TABLE IF NOT EXISTS wms_po_oms_allocation
(
    id String,
    whId Int64 DEFAULT 0,
    skuId String,
    uom String DEFAULT '',
    batch String DEFAULT '',
    poNo String DEFAULT '',
    omsAllocationLineId String,
    invoiceLineId String,
    obSessionId String,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(createdAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;

-- ============================================================
-- 14: wms_inb_qc_item_v2
-- ============================================================
DROP TABLE IF EXISTS wms_inb_qc_item_v2;
CREATE TABLE IF NOT EXISTS wms_inb_qc_item_v2
(
    id String,
    whId Int64 DEFAULT 0,
    sessionId String,
    taskId String,
    skuId String,
    uom String DEFAULT '',
    batch String DEFAULT '',
    bucket String DEFAULT '',
    price String DEFAULT '',
    qty Int32 DEFAULT 0,
    receivedQty Int32 DEFAULT 0,
    sampleSize Int32 DEFAULT 0,
    inspectionLevel String DEFAULT '',
    acceptableIssueSize Int32 DEFAULT 0,
    actualSkuId String DEFAULT '',
    actualUom String DEFAULT '',
    actualBatch String DEFAULT '',
    actualPrice String DEFAULT '',
    actualBucket String DEFAULT '',
    actualQty Int32 DEFAULT 0,
    actualQtyInside Int32 DEFAULT 0,
    parentItemId String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    createdBy String DEFAULT '',
    deactivatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    deactivatedBy String DEFAULT '',
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    movedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    movedBy String DEFAULT '',
    movedQty Int32 DEFAULT 0,
    processedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    uomInside String DEFAULT '',
    reason String DEFAULT '',
    subReason String DEFAULT '',
    batchOverridden String DEFAULT ''
)
ENGINE = ReplacingMergeTree(createdAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;

-- ============================================================
-- 32: wms_ira_approval
-- ============================================================
DROP TABLE IF EXISTS wms_ira_approval;
CREATE TABLE IF NOT EXISTS wms_ira_approval
(
    id String DEFAULT '',
    accountId Int64 DEFAULT 0,
    timestamp DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    approved String DEFAULT '{}',
    whId Int64 DEFAULT 0
)
ENGINE = ReplacingMergeTree(timestamp)
PARTITION BY toYYYYMM(timestamp)
ORDER BY (id)
SETTINGS index_granularity = 8192;

-- ============================================================
-- 35: wms_ira_manual_update
-- ============================================================
DROP TABLE IF EXISTS wms_ira_manual_update;
CREATE TABLE IF NOT EXISTS wms_ira_manual_update
(
    id String DEFAULT '',
    taskId String DEFAULT '',
    huId String DEFAULT '',
    accountId Int64 DEFAULT 0,
    timestamp DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    system String DEFAULT '',
    actual String DEFAULT '',
    whId Int64 DEFAULT 0
)
ENGINE = ReplacingMergeTree(timestamp)
PARTITION BY toYYYYMM(timestamp)
ORDER BY (id)
SETTINGS index_granularity = 8192;

-- ============================================================
-- 36: wms_ira_record
-- ============================================================
DROP TABLE IF EXISTS wms_ira_record;
CREATE TABLE IF NOT EXISTS wms_ira_record
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    binId String DEFAULT '',
    binStorageHUType String DEFAULT '',
    sourceHUId String DEFAULT '',
    sourceHUCode String DEFAULT '',
    skuId String DEFAULT '',
    uom String DEFAULT '',
    batch String DEFAULT '',
    qty Int32 DEFAULT 0,
    damagedQty Int32 DEFAULT 0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    createdBy String DEFAULT '',
    recordNo Int32 DEFAULT 0
)
ENGINE = ReplacingMergeTree(createdAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;

-- ============================================================
-- 38: wms_ira_session_sku
-- ============================================================
DROP TABLE IF EXISTS wms_ira_session_sku;
CREATE TABLE IF NOT EXISTS wms_ira_session_sku
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    sessionId String DEFAULT '',
    skuId String DEFAULT '',
    skuCode String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(createdAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;

-- ============================================================
-- 39: wms_ira_session_summary
-- ============================================================
DROP TABLE IF EXISTS wms_ira_session_summary;
CREATE TABLE IF NOT EXISTS wms_ira_session_summary
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    sessionId String DEFAULT '',
    skuId String DEFAULT '',
    uom String DEFAULT '',
    batch String DEFAULT '',
    totalCount Int32 DEFAULT 0,
    hitCount Int32 DEFAULT 0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(createdAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;

-- ============================================================
-- 41: wms_ira_worker_update
-- ============================================================
DROP TABLE IF EXISTS wms_ira_worker_update;
CREATE TABLE IF NOT EXISTS wms_ira_worker_update
(
    id String DEFAULT '',
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    huId String DEFAULT '',
    workerId String DEFAULT '',
    timestamp DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    mismatch String DEFAULT '',
    system String DEFAULT '{}',
    actual String DEFAULT '{}',
    whId Int64 DEFAULT 0
)
ENGINE = ReplacingMergeTree(timestamp)
PARTITION BY toYYYYMM(timestamp)
ORDER BY (id)
SETTINGS index_granularity = 8192;

-- ============================================================
-- 54: wms_worker_productivity
-- ============================================================
DROP TABLE IF EXISTS wms_worker_productivity;
CREATE TABLE IF NOT EXISTS wms_worker_productivity
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    workerId String DEFAULT '',
    date Date DEFAULT toDate('1970-01-01'),
    taskId String DEFAULT '',
    activeTime Int32 DEFAULT 0,
    qtyL2 Int32 DEFAULT 0,
    qtyL0 Int32 DEFAULT 0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(createdAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;

-- ============================================================
-- 58: wms_task_worker_assignment
-- ============================================================
DROP TABLE IF EXISTS wms_task_worker_assignment;
CREATE TABLE IF NOT EXISTS wms_task_worker_assignment
(
    taskId String DEFAULT '',
    workerId String DEFAULT '',
    assignedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    attrs String DEFAULT '',
    whId Int64 DEFAULT 0,
    mheId String DEFAULT '',
    id String DEFAULT '00000000-0000-0000-0000-000000000000',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(assignedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (taskId, workerId)
SETTINGS index_granularity = 8192;

-- ============================================================
-- 60: wms_ob_order
-- ============================================================
DROP TABLE IF EXISTS wms_ob_order;
CREATE TABLE IF NOT EXISTS wms_ob_order
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    tripCode String DEFAULT '',
    code String DEFAULT '',
    retailerId Int32 DEFAULT 0,
    retailerCode String DEFAULT '',
    retailerChannel String DEFAULT '',
    retailerName String DEFAULT '',
    tripDate DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    deliveryDate DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    priority Int32 DEFAULT 0,
    sessionId String DEFAULT '',
    active Bool DEFAULT true,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    salesmanCode String DEFAULT '',
    ginStatus String DEFAULT 'PENDING',
    ginTriggeredAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    cancelledAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    tripPriority Int32 DEFAULT 0,
    truckType String DEFAULT '',
    transporterCode String DEFAULT '',
    advanceReplenSessionId String DEFAULT '',
    orderType String DEFAULT '',
    loadingSeq Int32 DEFAULT 0,
    latestPickDate Date DEFAULT toDate('1970-01-01'),
    earliestPickDate Date DEFAULT toDate('1970-01-01'),
    documentType String DEFAULT 'DELIVERY_ORDER',
    orderReferenceId String DEFAULT '',
    orderReferenceCode String DEFAULT '',
    erpChannel String DEFAULT '',
    delinkedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    relinkedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    erpInvoiceCode String DEFAULT '',
    provisionalGinStatus String DEFAULT 'PENDING',
    provisionalGinTriggeredAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    erpInvoiceCodes String DEFAULT '[]'
)
ENGINE = ReplacingMergeTree(createdAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (whId, id)
SETTINGS index_granularity = 8192;

-- ============================================================
-- 79: wms_pd_pick_drop_item_inner_hu
-- ============================================================
DROP TABLE IF EXISTS wms_pd_pick_drop_item_inner_hu;
CREATE TABLE IF NOT EXISTS wms_pd_pick_drop_item_inner_hu
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    skuId String DEFAULT '',
    batch String DEFAULT '',
    uom String DEFAULT '',
    bucket String DEFAULT '',
    innerHUId String DEFAULT '',
    innerHUCode String DEFAULT '',
    huId String DEFAULT '',
    huCode String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    type String DEFAULT '',
    processedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    qty Int32 DEFAULT 1,
    innerHUKind String DEFAULT 'CARTON',
    iloc String DEFAULT ''
)
ENGINE = ReplacingMergeTree(createdAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;

-- ============================================================
-- 82: wms_hht_pick_item_reduction
-- ============================================================
DROP TABLE IF EXISTS wms_hht_pick_item_reduction;
CREATE TABLE IF NOT EXISTS wms_hht_pick_item_reduction
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '',
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    groupId String DEFAULT '',
    skuId String DEFAULT '',
    batch String DEFAULT '',
    uom String DEFAULT '',
    inventoryBinId String DEFAULT '',
    inventoryHUId String DEFAULT '',
    pickItemId String DEFAULT '',
    qty Int32 DEFAULT 0,
    newQty Int32 DEFAULT 0,
    reason String DEFAULT '',
    reducedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    reducedBy String DEFAULT ''
)
ENGINE = ReplacingMergeTree(reducedAt)
PARTITION BY toYYYYMM(sessionCreatedAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;

-- ============================================================
-- 83: wms_hht_pick_group
-- ============================================================
DROP TABLE IF EXISTS wms_hht_pick_group;
CREATE TABLE IF NOT EXISTS wms_hht_pick_group
(
    whId Int64 DEFAULT 0,
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    id String DEFAULT '',
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sblTaskId String DEFAULT '',
    sblZoneId String DEFAULT '',
    priority Int32 DEFAULT 0,
    huId String DEFAULT '',
    binId String DEFAULT '',
    binAssignedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    mappedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    mappedBy String DEFAULT ''
)
ENGINE = ReplacingMergeTree(createdAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;

-- ============================================================
-- 84: wms_bbulk_ptl_bin_reduction
-- ============================================================
DROP TABLE IF EXISTS wms_bbulk_ptl_bin_reduction;
CREATE TABLE IF NOT EXISTS wms_bbulk_ptl_bin_reduction
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '',
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    zoneId String DEFAULT '',
    groupId String DEFAULT '',
    chuId String DEFAULT '',
    visitId String DEFAULT '',
    chuAssignmentId String DEFAULT '',
    binAssignmentId String DEFAULT '',
    qty Int32 DEFAULT 0,
    newQty Int32 DEFAULT 0,
    reason String DEFAULT '',
    reducedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    reducedBy String DEFAULT ''
)
ENGINE = ReplacingMergeTree(reducedAt)
PARTITION BY toYYYYMM(sessionCreatedAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;

-- ============================================================
-- 85: wms_sbl_chu_reduction
-- ============================================================
DROP TABLE IF EXISTS wms_sbl_chu_reduction;
CREATE TABLE IF NOT EXISTS wms_sbl_chu_reduction
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '',
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    zoneId String DEFAULT '',
    inventoryHUId String DEFAULT '',
    visitId String DEFAULT '',
    binAssignmentId String DEFAULT '',
    chuAssignmentId String DEFAULT '',
    qty Int32 DEFAULT 0,
    newQty Int32 DEFAULT 0,
    reason String DEFAULT '',
    reducedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    reducedBy String DEFAULT ''
)
ENGINE = ReplacingMergeTree(reducedAt)
PARTITION BY toYYYYMM(sessionCreatedAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;

-- ============================================================
-- 86: wms_hht_pick_item
-- ============================================================
DROP TABLE IF EXISTS wms_hht_pick_item;
CREATE TABLE IF NOT EXISTS wms_hht_pick_item
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '',
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    groupId String DEFAULT '',
    skuId String DEFAULT '',
    batch String DEFAULT '',
    uom String DEFAULT '',
    qty Int32 DEFAULT 0,
    inventoryBinId String DEFAULT '',
    inventoryHUId String DEFAULT '',
    binAssignedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    parentItemId String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    pickedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    pickedBy String DEFAULT '',
    inventoryBinHUId String DEFAULT '',
    reductionApplied Bool DEFAULT false
)
ENGINE = ReplacingMergeTree(createdAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;

-- ============================================================
-- 87: wms_ccs_ptl_zone_inventory
-- ============================================================
DROP TABLE IF EXISTS wms_ccs_ptl_zone_inventory;
CREATE TABLE IF NOT EXISTS wms_ccs_ptl_zone_inventory
(
    whId Int64 DEFAULT 0,
    sessionId String DEFAULT '',
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    id String DEFAULT '',
    taskId String DEFAULT '',
    zoneId String DEFAULT '',
    skuId String DEFAULT '',
    batch String DEFAULT '',
    uom String DEFAULT '',
    qty Int32 DEFAULT 0,
    assigned Int32 DEFAULT 0,
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    price String DEFAULT ''
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(sessionCreatedAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;
