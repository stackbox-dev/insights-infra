-- ClickHouse table for WMS Storage Bins
-- Dimension table for storage bin information
-- Source: sbx_uat.wms.public.storage_bin

CREATE TABLE IF NOT EXISTS wms_storage_bins
(
    whId Int64 DEFAULT 0,
    id String,
    code String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    
    -- Indexes for common query patterns
    INDEX idx_whId whId TYPE minmax GRANULARITY 1,
    INDEX idx_code code TYPE bloom_filter(0.01) GRANULARITY 1
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id)  -- id is globally unique
SETTINGS index_granularity = 8192
COMMENT 'WMS Storage Bins dimension table';

-- Projection optimized for JOIN on id (primary enrichment pattern)
-- Already optimal since ORDER BY (id) is the primary key

-- Projection for warehouse + code lookups and reverse lookup by code
ALTER TABLE wms_storage_bins ADD PROJECTION proj_by_code (
    SELECT 
        code,
        id,
        whId,
        createdAt,
        updatedAt
    ORDER BY code
);