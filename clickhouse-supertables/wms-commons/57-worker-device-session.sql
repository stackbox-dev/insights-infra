-- ClickHouse table for WMS Worker Device Session
-- Dimension table for WMS Worker Device Session information
-- Source: digitaldc_prod.wms.public.worker_device_session

CREATE TABLE IF NOT EXISTS wms_worker_device_session
(
    id String DEFAULT '',
    workerId String DEFAULT '',
    otp String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    accessToken String DEFAULT '',
    provisionedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    deviceId String DEFAULT '',
    expiredAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    attrs String DEFAULT '',
    whId Int64 DEFAULT 0,
    expiryAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(provisionedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;