-- ClickHouse table for SBL Bin CHU
-- Dimension table for SBL bin to CHU assignments
-- Source: samadhan_prod.wms.public.sbl_bin_chu

CREATE TABLE IF NOT EXISTS wms_sbl_bin_chu
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '',
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sessionId String DEFAULT '',
    taskId String DEFAULT '',
    zoneId String DEFAULT '',
    binId String DEFAULT '',
    chuId String DEFAULT '',
    chuKindId String DEFAULT '',
    chuKind String DEFAULT '',
    assignedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    assignedBy String DEFAULT '',
    closedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    closedBy String DEFAULT '',
    deactivatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    hybrid bool DEFAULT false,
    recoId String DEFAULT '',
    maxVolume Float64 DEFAULT 0.0,
    maxWeight Float64 DEFAULT 0.0,
    ptlDemandGroupId String DEFAULT '',
    repacking bool DEFAULT false,
    shortage bool DEFAULT false,
    canBeRemovedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(assignedAt)
PARTITION BY toYYYYMM(sessionCreatedAt)
ORDER BY (id)
SETTINGS index_granularity = 8192
COMMENT 'SBL Bin CHU dimension table';