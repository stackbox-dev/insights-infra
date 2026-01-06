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
    predictedWorkTime Int32 DEFAULT 0,
    
    -- Indexes for common query patterns
    INDEX idx_whId whId TYPE minmax GRANULARITY 1,
    INDEX idx_sessionId sessionId TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_wave wave TYPE minmax GRANULARITY 1,
    INDEX idx_huId huId TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_zoneId zoneId TYPE bloom_filter(0.01) GRANULARITY 1
)
ENGINE = ReplacingMergeTree(assignedAt)
PARTITION BY toYYYYMM(sessionCreatedAt)
ORDER BY (id, sessionCreatedAt)
SETTINGS index_granularity = 8192;