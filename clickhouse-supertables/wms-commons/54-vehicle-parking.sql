-- ClickHouse table for WMS Vehicle Parking
-- Dimension table for Vehicle Parking information
-- Source: samadhan_prod.wms.public.vehicle_parking

CREATE TABLE IF NOT EXISTS wms_vehicle_parking
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    vehicleEventId String DEFAULT '',
    parkingSlotId String DEFAULT '',
    parkingSlotCode String DEFAULT '',
    parkingZoneId String DEFAULT '',
    parkingZoneCode String DEFAULT '',
    parkingZoneType String DEFAULT '',
    parkedInAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    parkedOutAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;