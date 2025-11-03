-- ClickHouse table for Order Upload
-- Source: public.orderUpload

CREATE TABLE IF NOT EXISTS backbone_orderUpload
(
    id Int32 DEFAULT 0,
    date Date DEFAULT toDate('1970-01-01'),
    branchId Int64 DEFAULT 0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    active Bool DEFAULT false,
    unmatchedRetailerCodes Array(String) DEFAULT [],
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    unmatchedSkus Array(String) DEFAULT [],
    isLineItemType Bool DEFAULT false,
    dataMode String DEFAULT 'MANUAL',
    extras String DEFAULT '{}',
    previouslyPlannedDiscardedInvoiceIds Array(Int32) DEFAULT []
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;
