-- ClickHouse table for WMS Inbound ASN
-- Dimension table for ASN (Advanced Shipping Notice) information
-- Source: samadhan_prod.wms.public.inb_asn

CREATE TABLE IF NOT EXISTS wms_inb_asn
(
    id String,
    whId Int64 DEFAULT 0,
    asnNo String DEFAULT '',
    sessionId String DEFAULT '',
    active Bool DEFAULT true,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    shipmentDate Nullable(Date32) DEFAULT NULL,
    deliveryNo String DEFAULT '',
    priority Int32 DEFAULT 0,
    asnType String DEFAULT ''
)
ENGINE = ReplacingMergeTree(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;