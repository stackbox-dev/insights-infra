-- ClickHouse table for HHT Pick Item Reduction

CREATE TABLE IF NOT EXISTS wms_hht_pick_item_reduction
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
    inventoryBinId String DEFAULT '',
    inventoryHUId String DEFAULT '',
    pickItemId String DEFAULT '',
    qty Int32 DEFAULT 0,
    newQty Int32 DEFAULT 0,
    reason String DEFAULT '',
    reducedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    reducedBy String DEFAULT ''
)
ENGINE = ReplacingMergeTree(reducedAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;