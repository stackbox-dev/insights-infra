-- ClickHouse table for WMS Inbound GRN
-- Dimension table for Inbound GRN information
-- Source: samadhan_prod.wms.public.inb_grn

CREATE TABLE IF NOT EXISTS wms_inb_grn
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sessionId String DEFAULT '',
    asnId String DEFAULT '',
    asnNo String DEFAULT '',
    status String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    processedForInternalDiscrepancyAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    submittedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    active bool DEFAULT true
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;