-- ClickHouse table for WMS Outbound Load Item
-- Dimension table for OB Load Item information
-- Source: samadhan_prod.wms.public.ob_load_item

CREATE TABLE IF NOT EXISTS wms_ob_load_item
(
    whId Int64 DEFAULT 0,
    id String,
    sessionId String,
    taskId String,
    tripId String,
    skuId String,
    skuClass String DEFAULT '',
    uom String DEFAULT '',
    qty Int32 DEFAULT 0,
    seq Int64 DEFAULT 0,
    loadedQty Int32 DEFAULT 0,
    loadedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    loadedBy String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    invoiceId String DEFAULT '',
    skuCategory String DEFAULT '',
    originalSkuId String DEFAULT '',
    batch String DEFAULT '',
    huId String DEFAULT '',
    huCode String DEFAULT '',
    mmTripId String DEFAULT '',
    innerHUId String DEFAULT '',
    innerHUCode String DEFAULT '',
    innerHUKind String DEFAULT '',
    binId String DEFAULT '',
    binHUId String DEFAULT '',
    binCode String DEFAULT '',
    parentItemId String DEFAULT '',
    classificationType String DEFAULT '',
    originalQty Int32 DEFAULT 0,
    originalUOM String DEFAULT '',
    repicked Bool DEFAULT False,
    invoiceCode String DEFAULT '',
    retailerId String DEFAULT '',
    retailerCode String DEFAULT ''
)
ENGINE = ReplacingMergeTree(loadedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;