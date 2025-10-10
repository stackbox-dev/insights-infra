-- ClickHouse table for WMS PLN IRA Cycle Step Bin
-- Dimension table for PLN IRA Cycle Step Bin information
-- Source: samadhan_prod.wms.public.pln_ira_cycle_step_bin

CREATE TABLE IF NOT EXISTS wms_pln_ira_cycle_step_bin
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    planId String DEFAULT '',
    stepId String DEFAULT '',
    areaId String DEFAULT '',
    zoneId String DEFAULT '',
    binId String DEFAULT '',
    position Int64 DEFAULT 0,
    huCount Int64 DEFAULT 0,
    effort Int64 DEFAULT 0,
    planned UInt8 DEFAULT 0,
    excluded UInt8 DEFAULT 0,
    state String DEFAULT '',
    recordedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    appendedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    deactivatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;