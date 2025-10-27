-- ClickHouse Table: trip_invoice
-- Source: postgres.public.trip_invoice

CREATE TABLE IF NOT EXISTS backbone_trip_invoice
(
    id String DEFAULT '',
    planId Int32 DEFAULT 0,
    invoiceId Int32 DEFAULT 0,
    nodeId Int64 DEFAULT 0,
    outletId Int32 DEFAULT 0,
    type String DEFAULT '',
    retry Bool DEFAULT false,
    retryTripInvoiceId String DEFAULT '',
    priority Int32 DEFAULT 0,
    visitId Int32 DEFAULT 0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    active Bool DEFAULT true,
    planningType String DEFAULT ''
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;