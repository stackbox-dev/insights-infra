-- ClickHouse table for WMS Inbound GRN Lines
-- Dimension table for GRN line information
-- Source: samadhan_prod.wms.public.inb_grn_line

CREATE TABLE IF NOT EXISTS wms_inb_grn_line
(
    id String,
    whId Int64 DEFAULT 0,
    sessionId String,
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    grnId String,
    asnId String,
    asnNo String DEFAULT '',
    asnLineId String DEFAULT '',
    skuId String,
    batch String DEFAULT '',
    price String DEFAULT '',
    uom String DEFAULT '',
    qty Int32 DEFAULT 0,
    bucket String DEFAULT '',
    huId String DEFAULT '',
    binId String,
    shortage Bool DEFAULT false,
    approvedBy Int64 DEFAULT 0,
    approvedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    reason String DEFAULT '',
    subReason String DEFAULT '',
    deactivatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedBy Int64 DEFAULT 0
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;