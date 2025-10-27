-- ClickHouse table for market_activity
CREATE TABLE IF NOT EXISTS razum_market_activity
(
    user_id Int32 DEFAULT 0,
    timestamp Int64 DEFAULT 0,
    identifier Int32 DEFAULT 0,
    activity String DEFAULT '',
    
    -- Indexes for faster lookups
    INDEX idx_user_id user_id TYPE minmax GRANULARITY 1,
    INDEX idx_identifier identifier TYPE bloom_filter(0.01) GRANULARITY 1
)
ENGINE = ReplacingMergeTree()
PARTITION BY toYYYYMM(toDateTime(timestamp))
ORDER BY (user_id, timestamp)
SETTINGS index_granularity = 8192
COMMENT 'Market activity table migrated from Postgres market_activity';