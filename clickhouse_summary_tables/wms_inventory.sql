CREATE TABLE IF NOT EXISTS inventory 
(
    whId Int64,
    id UUID,
    huId String,
    huCode String,
    huKind String,
    huWeight Float64 DEFAULT 0,
    huOnHold Bool,
    huRendered Bool,
    huLockTaskId UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    isBinHu Bool,
    areaType String DEFAULT '',
    areaCode String DEFAULT '',
    zoneFace String DEFAULT '',
    zoneCode String DEFAULT '',
    binType String DEFAULT '',
    binCode String DEFAULT '',
    binStatus String DEFAULT '',
    binCapacity Int32 DEFAULT 0,
    outerHUCode String DEFAULT '',
    outerHUKind String DEFAULT '',
    skuId String,
    skuCode String,
    skuName String,
    skuInventoryType String DEFAULT '',
    productCode String,
    category String,
    categoryGroup String,
    skuClassification String,
    plantCode String DEFAULT '',
    brand String DEFAULT '',
    bucket String,
    inclusionStatus String,
    uom String,
    batch String DEFAULT '',
    manufactureDate Date32 DEFAULT toDate32('1970-01-01'),
    expiryDate Date32 DEFAULT toDate32('1970-01-01'),
    price String DEFAULT '',
    quantLockMode String,
    qty Int32,
    qtyL0 Int64,
    huUpdatedAt DateTime64(3, 'UTC') DEFAULT toDateTime64('1970-01-01 00:00:00', 3, 'UTC'),
    quantUpdatedAt DateTime64(3, 'UTC') DEFAULT toDateTime64('1970-01-01 00:00:00', 3, 'UTC'),
    updatedAt DateTime64(3, 'UTC') DEFAULT toDateTime64('1970-01-01 00:00:00', 3, 'UTC'),
    binTypeId UUID DEFAULT '00000000-0000-0000-0000-000000000000',
    usage Float64 DEFAULT 0,
    huCountBlocked Bool DEFAULT false,
    iloc String DEFAULT '',
    is_deleted Bool DEFAULT false,
    deleted_at DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(updatedAt)
ORDER BY (id)
TTL deleted_at + INTERVAL 1 MINUTE DELETE
   WHERE is_deleted = 1;