-- ClickHouse table for WMS PLN IRA Cycle Step
-- Dimension table for PLN IRA Cycle Step information
-- Source: samadhan_prod.wms.public.pln_ira_cycle_step

CREATE TABLE IF NOT EXISTS wms_pln_ira_cycle_step
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    planId String DEFAULT '',
    date Date DEFAULT toDate('1970-01-01'),
    plannedStartTimestamp DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    state String DEFAULT '',
    plannedHuCount Int32 DEFAULT 0,
    startTimestamp DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    endTimestamp DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    iraSessionId String DEFAULT '',
    iraSessionCreatedBy Int64 DEFAULT 0,
    plannedBinCount Int32 DEFAULT 0,
    unplannedBinCount Int32 DEFAULT 0,
    coveredPlannedBinCount Int32 DEFAULT 0,
    coveredUnplannedBinCount Int32 DEFAULT 0,
    spilledPlannedBinCount Int32 DEFAULT 0,
    spilledUnplannedBinCount Int32 DEFAULT 0,
    skippedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    skippedByUserId Int64 DEFAULT 0,
    skippedByUserSessionId String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;