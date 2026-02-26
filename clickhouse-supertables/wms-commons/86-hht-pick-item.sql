-- ClickHouse table for WMS hht_pick_item
-- Fact table for HHT pick item events
-- Source: samadhan_prod.wms.public.hht_pick_item

CREATE TABLE IF NOT EXISTS wms_hht_pick_item
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '',
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    groupId String DEFAULT '',
    skuId String DEFAULT '',
    batch String DEFAULT '',
    uom String DEFAULT '',
    qty Int32 DEFAULT 0,
    inventoryBinId String DEFAULT '',
    inventoryHUId String DEFAULT '',
    binAssignedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    parentItemId String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    pickedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    pickedBy String DEFAULT '',
    inventoryBinHUId String DEFAULT '',
    reductionApplied Bool DEFAULT false
)
ENGINE = ReplacingMergeTree(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;