-- ClickHouse table for WMS Vehicle Event Trip
-- Dimension table for Vehicle Event Trip information
-- Source: samadhan_prod.wms.public.vehicle_event_trip

CREATE TABLE IF NOT EXISTS wms_vehicle_event_trip
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    vehicleEventId String DEFAULT '',
    sessionId String DEFAULT '',
    tripId String DEFAULT '',
    tripCode String DEFAULT '',
    active bool DEFAULT false,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;