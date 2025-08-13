-- ClickHouse table for WMS Trip Relations
-- Dimension table for trip relationship information
-- Source: sbx_uat.wms.internal.trip_relation_rekeyed1

CREATE TABLE IF NOT EXISTS wms_trip_relations
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '',
    sessionId String,
    xdock String DEFAULT '',
    parentTripId String DEFAULT '',
    childTripId String,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    
    -- Indexes for common query patterns
    INDEX idx_whId whId TYPE minmax GRANULARITY 1,
    INDEX idx_sessionId sessionId TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_parentTripId parentTripId TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_childTripId childTripId TYPE bloom_filter(0.01) GRANULARITY 1
)
ENGINE = ReplacingMergeTree(createdAt)
ORDER BY (sessionId, childTripId)  -- Primary key for this rekeyed table
SETTINGS index_granularity = 8192,
         min_age_to_force_merge_seconds = 180
COMMENT 'WMS Trip Relations dimension table';

-- Add projection for parent-child lookups
ALTER TABLE wms_trip_relations ADD PROJECTION IF NOT EXISTS by_parent_trip (
    SELECT * ORDER BY (parentTripId, childTripId)
);

-- Materialize the projection
ALTER TABLE wms_trip_relations MATERIALIZE PROJECTION by_parent_trip;