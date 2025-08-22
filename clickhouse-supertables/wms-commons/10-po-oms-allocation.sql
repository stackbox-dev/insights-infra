-- ClickHouse table for WMS PO OMS Allocation
-- Dimension table for purchase order OMS allocation information
-- Source: samadhan_prod.wms.public.po_oms_allocation

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
ORDER BY (id)
SETTINGS index_granularity = 8192;