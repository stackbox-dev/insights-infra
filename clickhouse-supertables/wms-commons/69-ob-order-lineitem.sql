CREATE TABLE IF NOT EXISTS wms_ob_order_lineitem
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    orderId String DEFAULT '',
    skuId String DEFAULT '',
    uom String DEFAULT 'L0',
    batch String DEFAULT '',
    qty Int32 DEFAULT 0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    extraFields String DEFAULT '{}',
    value Int32 DEFAULT 0,
    huId String DEFAULT '',
    huCode String DEFAULT '',
    huWeight Float64 DEFAULT 0.0,
    deliveryOrder String DEFAULT '',
    customerOrderQty Int32 DEFAULT 0,
    deliveryOrderQty Int32 DEFAULT 0,
    processFlag String DEFAULT '',
    promoCode String DEFAULT '',
    promoLineType String DEFAULT '',
    ratio Int32 DEFAULT 0,
    salesAllocationLossReceivedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    deactivatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    lineCode String DEFAULT '',
    deactivationReason String DEFAULT ''
)
ENGINE = ReplacingMergeTree(deactivatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;