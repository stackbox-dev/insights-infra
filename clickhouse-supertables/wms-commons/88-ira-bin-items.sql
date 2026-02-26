-- Table for IRA Bin Items
-- Source: public.ira_bin_items

CREATE TABLE IF NOT EXISTS wms_ira_bin_items
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    binId String DEFAULT '',
    skuId String DEFAULT '',
    uom String DEFAULT '',
    systemQty Int32 DEFAULT 0,
    systemDamagedQty Int32 DEFAULT 0,
    physicalQty Int32 DEFAULT 0,
    physicalDamagedQty Int32 DEFAULT 0,
    finalQty Int32 DEFAULT 0,
    finalDamagedQty Int32 DEFAULT 0,
    issue String DEFAULT '',
    state String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    scannedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    scannedBy String DEFAULT '',
    approvedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    approvedBy String DEFAULT '',
    batch String DEFAULT '',
    processedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sourceHUId String DEFAULT '',
    sourceHUCode String DEFAULT '',
    transactionId String DEFAULT '',
    binStorageHUType String DEFAULT '',
    deactivatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedBy String DEFAULT '',
    huSameBinBeforeIRA String DEFAULT 'NA',
    recordNo Int32 DEFAULT 1,
    hlrStatus String DEFAULT '',
    outerHUId String DEFAULT '',
    outerHuSameBinBeforeIRA Bool DEFAULT false,
    PRIMARY KEY (id)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;