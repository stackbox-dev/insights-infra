-- ClickHouse table for Invoice
-- Source: public.invoice

CREATE TABLE IF NOT EXISTS backbone_invoice
(
    id Int32 DEFAULT 0,
    code String DEFAULT '',
    date Date DEFAULT '1970-01-01',
    salesmanId Int64 DEFAULT 0,
    value Float64 DEFAULT 0.0,
    details String DEFAULT '{}',
    modeOfCredit String DEFAULT '',
    branchId Int64 DEFAULT 0,
    active Bool DEFAULT true,
    retailerId Int32 DEFAULT 0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    virtual Bool DEFAULT false,
    dbUpdatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    version Int32 DEFAULT 0,
    isSync Bool DEFAULT false,
    modeOfPayment String DEFAULT '',
    message String DEFAULT '',
    erpCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    deliveryType String DEFAULT '',
    supplierId Int32 DEFAULT 0,
    type String DEFAULT 'INVOICE',
    distributor String DEFAULT '',
    orderCode String DEFAULT '',
    tags String DEFAULT '{}',
    masterShipmentCode String DEFAULT '',
    principalId Int64 DEFAULT 0,
    invoiceCode String DEFAULT ''
)
ENGINE = ReplacingMergeTree(dbUpdatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;