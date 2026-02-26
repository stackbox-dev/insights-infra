-- ClickHouse table for CCS SBL HU Visit
-- Event table for SBL HU visit tracking
-- Source: samadhan_prod.wms.public.ccs_sbl_hu_visit

CREATE TABLE IF NOT EXISTS wms_ccs_sbl_hu_visit
(
    whId Int64 DEFAULT 0,
    sessionId String DEFAULT '',
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    id String DEFAULT '',
    wave Int32 DEFAULT 0,
    taskId String DEFAULT '',
    zoneId String DEFAULT '',
    huId String DEFAULT '',
    assignedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    predictedToArriveAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    divertedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    packedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    predictedWorkTime Int32 DEFAULT 0
)
ENGINE = ReplacingMergeTree(assignedAt)
PARTITION BY toYYYYMM(sessionCreatedAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;