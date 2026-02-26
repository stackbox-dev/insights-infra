
CREATE TABLE wms_ob_qa_lineitem
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    invoiceId String DEFAULT '',
    invoiceCode String DEFAULT '',
    skuId String DEFAULT '',
    skuClass String DEFAULT '',
    skuCategory String DEFAULT '',
    uom String DEFAULT '',
    orderedQty Int32 DEFAULT 0,
    pickedQty Int32 DEFAULT 0,
    packedQty Int32 DEFAULT 0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedBy String DEFAULT '',
    tripId String DEFAULT '',
    tripCode String DEFAULT '',
    batch String DEFAULT '',
    retailerId String DEFAULT '',
    retailerCode String DEFAULT ''
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;