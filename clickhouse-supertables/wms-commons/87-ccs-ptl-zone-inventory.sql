-- ClickHouse table for CCS PTL Zone Inventory
-- Dimension table for PTL zone inventory information
-- Source: <db>.wms.public.ccs_ptl_zone_inventory

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
ORDER BY (id) 
SETTINGS index_granularity = 8192;
