CREATE TABLE IF NOT EXISTS backbone_invoice_tray
(
    id String DEFAULT '',
    invoiceId Int32 DEFAULT 0,
    nodeId Int64 DEFAULT 0,
    planDate Date DEFAULT toDate('1970-01-01'),
    status String DEFAULT '',
    planId Int32 DEFAULT 0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    orderUploadId Int32 DEFAULT 0,
    planningType String DEFAULT '',
    serviceType String DEFAULT '',
    priority Bool DEFAULT false,
    movementType String DEFAULT '',
    fulfillmentMethod String DEFAULT '',
    supplierSalesmanId Int64 DEFAULT 0,
    retryUploadId Int32 DEFAULT 0,
    modeOfPayment String DEFAULT '',
    isTopup Bool DEFAULT false
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;
