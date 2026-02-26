-- ClickHouse table for WMS OB QC CHU Item
-- Fact table for outbound QC CHU items
-- Source: samadhan_prod.wms.public.ob_qc_chu_item

CREATE TABLE IF NOT EXISTS wms_ob_qc_chu_item
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '',
    sessionId String DEFAULT '',
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    taskId String DEFAULT '',
    qcChuId String DEFAULT '',
    chuId String DEFAULT '',
    skuId String DEFAULT '',
    batch String DEFAULT '',
    uom String DEFAULT '',
    qty Int32 DEFAULT 0,
    inventoryHUId String DEFAULT '',
    binId String DEFAULT '',
    fulfillmentType String DEFAULT '',
    workerId String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(createdAt)
PARTITION BY toYYYYMM(sessionCreatedAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;