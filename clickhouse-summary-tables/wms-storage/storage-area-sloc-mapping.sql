-- ClickHouse table for WMS Storage Area SLOC Mapping
-- Maps storage areas to Storage Location (SLOC) codes for ERP-WMS integration
-- Source: sbx_uat.wms.public.storage_area_sloc_mapping

CREATE TABLE IF NOT EXISTS wms_storage_area_sloc_mapping
(
    -- Core Identifiers (Composite Primary Key)
    wh_id Int64,
    area_code String,
    quality String,
    sloc String,
    
    -- SLOC Configuration
    sloc_description String DEFAULT '',
    client_quality String DEFAULT '',
    inventory_visible Bool DEFAULT false,
    erp_to_wms Bool DEFAULT false,
    iloc String DEFAULT '',
    
    -- System Fields
    deactivatedAt Nullable(DateTime64(3)),
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    is_snapshot Bool DEFAULT false,
    event_time DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(event_time)
ORDER BY (wh_id, area_code, quality, sloc)
TTL toDateTime(coalesce(deactivatedAt, toDateTime64('2099-12-31 23:59:59', 3))) + INTERVAL 1 MINUTE DELETE WHERE deactivatedAt IS NOT NULL
SETTINGS index_granularity = 8192,
         min_age_to_force_merge_seconds = 180
COMMENT 'Storage area to SLOC mapping for ERP-WMS integration and inventory visibility management';