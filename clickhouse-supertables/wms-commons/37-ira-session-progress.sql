-- ClickHouse table for WMS IRA Session Progress
-- Dimension table for IRA Session Progress information
-- Source: samadhan_prod.wms.public.ira_session_progress

CREATE TABLE IF NOT EXISTS wms_ira_session_progress
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    bins Int32 DEFAULT 0,
    binsCovered Int32 DEFAULT 0,
    accurateBins Int32 DEFAULT 0,
    plannedBins Int32 DEFAULT 0,
    plannedBinsCovered Int32 DEFAULT 0,
    plannedAccurateBins Int32 DEFAULT 0,
    linesCovered Int32 DEFAULT 0,
    missingHUs Int32 DEFAULT 0,
    excessHUs Int32 DEFAULT 0,
    missingUOMs String DEFAULT '[]',
    excessUOMs String DEFAULT '[]',
    recordLines String DEFAULT '[]',
    finalRecordLines String DEFAULT '{}',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;
