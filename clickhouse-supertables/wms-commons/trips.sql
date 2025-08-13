-- ClickHouse table for WMS Trips
-- Dimension table for trip information
-- Source: sbx_uat.wms.public.trip

CREATE TABLE IF NOT EXISTS wms_trips
(
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    whId Int64 DEFAULT 0,
    sessionId String DEFAULT '',
    id String,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    bbId String DEFAULT '',
    code String DEFAULT '',
    type String DEFAULT '',
    priority Int32 DEFAULT 0,
    dockdoorId String DEFAULT '',
    dockdoorCode String DEFAULT '',
    vehicleId String DEFAULT '',
    vehicleNo String DEFAULT '',
    vehicleType String DEFAULT '',
    deliveryDate Int32 DEFAULT 0,  -- Days since Unix epoch from Debezium
    deliveryDateActual Date ALIAS toDate('1970-01-01') + deliveryDate,  -- Computed actual date
    
    -- Indexes for common query patterns
    INDEX idx_whId whId TYPE minmax GRANULARITY 1,
    INDEX idx_sessionId sessionId TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_code code TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_type type TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_deliveryDate deliveryDate TYPE minmax GRANULARITY 1
)
ENGINE = ReplacingMergeTree(createdAt)
ORDER BY (id)  -- id is globally unique
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop',
         min_age_to_force_merge_seconds = 180
COMMENT 'WMS Trips dimension table';

-- Add projection for common query pattern (sessionId)
ALTER TABLE wms_trips ADD PROJECTION IF NOT EXISTS by_session (
    SELECT * ORDER BY (sessionId, createdAt)
);

-- Add projection for delivery date lookups
ALTER TABLE wms_trips ADD PROJECTION IF NOT EXISTS by_delivery_date (
    SELECT * ORDER BY (whId, deliveryDate, id)
);

-- Materialize the projections
ALTER TABLE wms_trips MATERIALIZE PROJECTION by_session;
ALTER TABLE wms_trips MATERIALIZE PROJECTION by_delivery_date;