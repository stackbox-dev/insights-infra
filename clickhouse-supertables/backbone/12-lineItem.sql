-- ClickHouse table for LineItem
-- Source: public.lineItem

CREATE TABLE IF NOT EXISTS backbone_lineItem
(
    id Int32 DEFAULT 0,
    invoiceId Int32 DEFAULT 0,
    skuId Int32 DEFAULT 0,
    quantity Int32 DEFAULT 0,
    price Float64 DEFAULT 0.0,
    value Float64 DEFAULT 0.0,
    details String DEFAULT '{}',
    active Bool DEFAULT true,
    batch String DEFAULT '',
    version Int32 DEFAULT 0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    parentId Int32 DEFAULT 0,
    skuNewId String DEFAULT '',
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    freebie Bool DEFAULT false,
    description String DEFAULT '',
    externalId String DEFAULT '',
    shipmentId String DEFAULT '',
    shipmentCode String DEFAULT '',
    weight Float64 DEFAULT 0.0
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;
