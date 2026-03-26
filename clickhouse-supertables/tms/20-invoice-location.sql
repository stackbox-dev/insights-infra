-- ClickHouse table for Invoice Location
-- Source: public.invoice_location

CREATE TABLE IF NOT EXISTS tms_invoice_location
(
    id String DEFAULT '',
    invoiceId Int32 DEFAULT 0,
    latitude Float64 DEFAULT 0.0,
    longitude Float64 DEFAULT 0.0,
    geoAccuracy Float64 DEFAULT 0.0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    stateId Int32 DEFAULT 0
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;
