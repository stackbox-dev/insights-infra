-- ClickHouse table for Line Item State
-- Source: public.line_item_state

CREATE TABLE IF NOT EXISTS backbone_line_item_state
(
    id String DEFAULT '',
    lineItemId Int32 DEFAULT 0,
    stateId Int32 DEFAULT 0,
    invoiceId Int32 DEFAULT 0,
    deliveredQuantity Int32 DEFAULT 0,
    deliveredValue Float64 DEFAULT 0.0,
    failReasons Array(String) DEFAULT [],
    images Array(String) DEFAULT [],
    active Bool DEFAULT true,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    deliveredWeight Float64 DEFAULT 0.0,
    dbUpdatedAt DateTime64(3) DEFAULT now()
)
ENGINE = ReplacingMergeTree(dbUpdatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;