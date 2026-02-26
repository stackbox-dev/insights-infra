-- ClickHouse table for Storage Bin Type Best Fit
-- Dimension table for storage bin type best fit configuration
-- Source: public.storage_bin_type_best_fit

CREATE TABLE IF NOT EXISTS wms_storage_bin_type_best_fit
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    binTypeId String DEFAULT '',
    skuId String DEFAULT '',
    uom String DEFAULT '',
    bestFitCount Int64 DEFAULT 0,
    active Bool DEFAULT true,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    attrs String DEFAULT '{}'  
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192