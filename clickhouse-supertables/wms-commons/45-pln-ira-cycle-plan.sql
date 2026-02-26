-- ClickHouse table for WMS PLN IRA Cycle Plan
-- Dimension table for PLN IRA Cycle Plan information
-- Source: samadhan_prod.wms.public.pln_ira_cycle_plan

CREATE TABLE IF NOT EXISTS wms_pln_ira_cycle_plan
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    mode String DEFAULT '',
    binSelectionMode String DEFAULT '',
    startDate Date DEFAULT '1970-01-01',
    endDate Date DEFAULT '1970-01-01',
    startTimeInSeconds Int64 DEFAULT 0,
    excludeDates String DEFAULT '[]',
    userAccountId Int64 DEFAULT 0,
    userAccountSessionId String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;