
CREATE TABLE IF NOT EXISTS wms_vehicle_event_trip
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '',
    vehicleEventId String DEFAULT '',
    sessionId String DEFAULT '',
    tripId String DEFAULT '',
    tripCode String DEFAULT '',
    active Bool DEFAULT true,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;