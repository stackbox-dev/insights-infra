-- ClickHouse table for WMS Pick Drop Item Inner HU
-- Fact table for pick/drop inner handling units
-- Source: samadhan_prod.wms.public.pd_pick_drop_item_inner_hu


CREATE TABLE IF NOT EXISTS wms_pd_pick_drop_item_inner_hu
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    skuId String DEFAULT '',
    batch String DEFAULT '',
    uom String DEFAULT '',
    bucket String DEFAULT '',
    innerHUId String DEFAULT '',
    innerHUCode String DEFAULT '',
    huId String DEFAULT '',
    huCode String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    type String DEFAULT '',
    processedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    qty Int32 DEFAULT 1,
    innerHUKind String DEFAULT 'CARTON',
    iloc String DEFAULT ''
)
ENGINE = ReplacingMergeTree(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;