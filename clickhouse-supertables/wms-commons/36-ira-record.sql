-- ClickHouse table for WMS IRA Record
-- Dimension table for IRA Record information
-- Source: samadhan_prod.wms.public.ira_record

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
ORDER BY (id)
SETTINGS index_granularity = 8192;