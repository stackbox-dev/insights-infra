-- ClickHouse table for WMS Storage Area SLOC Mapping
-- Maps storage areas to Storage Location (SLOC) codes for ERP-WMS integration
-- Source: sbx_uat.wms.public.storage_area_sloc (direct from source topic)

CREATE TABLE IF NOT EXISTS wms_storage_area_sloc
(
    -- Core Identifiers 
    id String,
    whId Int64,
    areaCode String,
    quality String,
    sloc String,
    
    -- SLOC Configuration
    slocDescription String DEFAULT '',
    clientQuality String DEFAULT '',
    inventoryVisible Bool DEFAULT false,
    erpToWMS Bool DEFAULT false,
    iloc String DEFAULT '',
    
    -- System Fields
    deactivatedAt Nullable(DateTime64(3)),
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (whId, areaCode, quality, iloc)
TTL toDateTime(coalesce(deactivatedAt, toDateTime64('2099-12-31 23:59:59', 3))) + INTERVAL 1 MINUTE DELETE WHERE deactivatedAt IS NOT NULL
SETTINGS index_granularity = 8192,
         min_age_to_force_merge_seconds = 180,
         deduplicate_merge_projection_mode = 'drop'
COMMENT 'Storage area to SLOC mapping for ERP-WMS integration and inventory visibility management';