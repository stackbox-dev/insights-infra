-- ClickHouse table for CCS PTL CHU Visit
-- Event table for PTL (Pick-to-Light) CHU visit tracking
-- Source: samadhan_prod.wms.public.ccs_ptl_chu_visit

CREATE TABLE IF NOT EXISTS wms_ccs_ptl_chu_visit
(
    whId Int64 DEFAULT 0,
    sessionId String DEFAULT '',
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    id String DEFAULT '',
    groupId String DEFAULT '',
    chuId String DEFAULT '',
    taskId String DEFAULT '',
    zoneId String DEFAULT '',
    assignedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    predictedToArriveAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    divertedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    packedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    chuFull UInt8 DEFAULT 0,
    predictedWorkTime Int32 DEFAULT 0,
    chuStatusId String DEFAULT '',
    hybridExit UInt8 DEFAULT 0,
    
    -- Indexes for common query patterns
    INDEX idx_whId whId TYPE minmax GRANULARITY 1,
    INDEX idx_sessionId sessionId TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_chuId chuId TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_zoneId zoneId TYPE bloom_filter(0.01) GRANULARITY 1
)
ENGINE = ReplacingMergeTree(assignedAt)
PARTITION BY toYYYYMM(sessionCreatedAt)
ORDER BY (id, sessionCreatedAt)
SETTINGS index_granularity = 8192;