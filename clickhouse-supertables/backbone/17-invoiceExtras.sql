-- ClickHouse table for Invoice Extras
-- Source: public.invoiceExtras

CREATE TABLE IF NOT EXISTS backbone_invoiceExtras
(
    invoiceId Int32 DEFAULT 0,
    state String DEFAULT '',
    stateId Int32 DEFAULT 0,
    plannedDate String DEFAULT '',
    nodeId Int64 DEFAULT 0,
    dbUpdatedAt DateTime64(3) DEFAULT now()
)
ENGINE = ReplacingMergeTree(dbUpdatedAt)
PARTITION BY toYYYYMM(dbUpdatedAt)
ORDER BY (invoiceId, nodeId)
SETTINGS index_granularity = 8192;