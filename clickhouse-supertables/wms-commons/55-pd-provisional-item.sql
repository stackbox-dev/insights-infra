-- ClickHouse table for WMS PD Provisional Item
-- Dimension table for PD Provisional Item information
-- Source: samadhan_prod.wms.public.pd_provisional_item

CREATE TABLE IF NOT EXISTS wms_pd_provisional_item
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    sessionId String DEFAULT '',
    taskKind String DEFAULT '',
    taskSubKind String DEFAULT '',
    taskKey String DEFAULT '',
    huId String DEFAULT '',
    huCode String DEFAULT '',
    skuId String DEFAULT '',
    batch String DEFAULT '',
    uom String DEFAULT '',
    bucket String DEFAULT '',
    qty Int32 DEFAULT 0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    inputSourceBinId String DEFAULT '',
    sourceBinId String DEFAULT '',
    sourceBinCode String DEFAULT '',
    sourceBinHUId String DEFAULT '',
    sourceBinAssignedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    destBinId String DEFAULT '',
    destBinCode String DEFAULT '',
    destBinHUId String DEFAULT '',
    destBinAssignedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    huEqUOM String DEFAULT '',
    priority Int32 DEFAULT 0,
    pathZoneIds String DEFAULT '',
    pathZoneCodes String DEFAULT '',
    parentItemId String DEFAULT '',
    carrierHUFormedId String DEFAULT '',
    destZoneId String DEFAULT '',
    preferredDestBinTypeId String DEFAULT '',
    pathAssignedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    pickHU bool DEFAULT false,
    inputDestBinId String DEFAULT '',
    inputDestHUId String DEFAULT '',
    eligibleDropLocations String DEFAULT '{}',
    scanSourceHUKind String DEFAULT 'NONE',
    pickSourceHUKind String DEFAULT 'NONE',
    carrierHUKind String DEFAULT 'NONE',
    categoryGroup String DEFAULT '',
    taint String DEFAULT '',
    destBucket String DEFAULT '',
    innerCarrierHUKey String DEFAULT '',
    innerCarrierHUFormedId String DEFAULT '',
    innerCarrierHUKindId String DEFAULT '',
    innerCarrierHUKind String DEFAULT 'NONE',
    innerHUIndex Int32 DEFAULT 0,
    deactivatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    iloc String DEFAULT '',
    destIloc String DEFAULT '',
    state String DEFAULT 'INITIATED',
    attrs String DEFAULT '{}'
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;