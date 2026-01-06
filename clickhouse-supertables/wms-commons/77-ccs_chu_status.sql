-- ClickHouse table for CCS CHU Status
-- Event table for CHU (Consolidated Handling Unit) status tracking
-- Source: samadhan_prod.wms.public.ccs_chu_status

CREATE TABLE IF NOT EXISTS wms_ccs_chu_status
(
    whId Int64 DEFAULT 0,
    sessionId String DEFAULT '',
    sessionCreatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    id String DEFAULT '',
    chuId String DEFAULT '',
    type String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    packedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    sblTaskId String DEFAULT '',
    qcParamsId String DEFAULT '',
    qcScoreUpdatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    qcScore Float64 DEFAULT 0.0,
    qcThreshold Float64 DEFAULT 0.0,
    qcDivert bool DEFAULT false,
    qcMinWeight Float64 DEFAULT 0.0,
    qcWeight Float64 DEFAULT 0.0,
    qcMaxWeight Float64 DEFAULT 0.0,
    qcCompletedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    repackCount Int32 DEFAULT 0,
    sblZoneId String DEFAULT '',
    sblWave Int32 DEFAULT 0,
    sblPackedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    qcValue Float64 DEFAULT 0.0,
    xdock String DEFAULT '',
    qcActualWt Float64 DEFAULT 0.0,
    qcActualWtMeasuredAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    qcMandatoryDivert bool DEFAULT 0,
    qcSblProd Float64 DEFAULT 0.0,
    qcPtlProd Float64 DEFAULT 0.0,
    mmTripId String DEFAULT '',
    lmTripId String DEFAULT '',
    invoiceIds String DEFAULT '[]',  -- JSON array
    sblShort bool DEFAULT false,
    ptlShort bool DEFAULT false,
    
    -- Indexes for common query patterns
    INDEX idx_whId whId TYPE minmax GRANULARITY 1,
    INDEX idx_sessionId sessionId TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_chuId chuId TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_type type TYPE bloom_filter(0.01) GRANULARITY 1
)
ENGINE = ReplacingMergeTree(createdAt)
PARTITION BY toYYYYMM(sessionCreatedAt)
ORDER BY (id, sessionCreatedAt)
SETTINGS index_granularity = 8192;