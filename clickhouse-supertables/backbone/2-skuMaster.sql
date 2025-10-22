-- ClickHouse table for skuMaster
-- Dimension table for SKU Master information
-- Source: backbone.public.skuMaster

CREATE TABLE IF NOT EXISTS backbone_skuMaster
(
    id Int32,
    principalId Int64 DEFAULT 0,
    categoryGroup String DEFAULT '',
    category String DEFAULT '',
    subCategory String DEFAULT '',
    brand String DEFAULT '',
    brandName String DEFAULT '',
    productCode String DEFAULT '',
    skuCode String DEFAULT '',
    skuDescription String DEFAULT '',
    consumerUpc Int32 DEFAULT 0,
    grossWtWithCase Float64 DEFAULT 0.0,
    netWt Float64 DEFAULT 0.0,
    caseVolume Float64 DEFAULT 0.0,
    caseEANCode String DEFAULT '',
    pieceEANCode String DEFAULT '',
    active Bool DEFAULT true,
    dirty Bool DEFAULT false,
    retailUpc Int32 DEFAULT 0,
    type String DEFAULT '',
    caseWidth Float64 DEFAULT 0.0,
    caseHeight Float64 DEFAULT 0.0,
    caseLength Float64 DEFAULT 0.0,
    build String DEFAULT 'NORMAL',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    images Array(String) DEFAULT [],
    fulfillmentType String DEFAULT 'NORMAL',
    newId String DEFAULT '',
    extras String DEFAULT '{}',
    class String DEFAULT '',
    hsn String DEFAULT '',
    uom String DEFAULT '',
    L2InL3 Int32 DEFAULT 0,
    shelfLife Int32 DEFAULT 0,
    inventoryType String DEFAULT 'FG'
)
ENGINE = ReplacingMergeTree(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;