-- ClickHouse table for WMS Trip Relations
-- Dimension table for trip relationship information
-- Source: sbx_uat.wms.public.trip_relation

CREATE TABLE IF NOT EXISTS wms_trip_relations
(
    whId Int64 DEFAULT 0,
    id String,  -- UUID, globally unique primary key
    sessionId String DEFAULT '',
    xdock String DEFAULT '',
    parentTripId String DEFAULT '',
    childTripId String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    
    -- Indexes for common query patterns
    INDEX idx_whId whId TYPE minmax GRANULARITY 1,
    INDEX idx_sessionId sessionId TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_parentTripId parentTripId TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_childTripId childTripId TYPE bloom_filter(0.01) GRANULARITY 1
)
ENGINE = ReplacingMergeTree(createdAt)
ORDER BY (id)  -- id is the unique identifier from source
SETTINGS index_granularity = 8192,
         min_age_to_force_merge_seconds = 180
COMMENT 'WMS Trip Relations dimension table';
