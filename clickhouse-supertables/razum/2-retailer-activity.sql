
CREATE TABLE IF NOT EXISTS razum_retailer_activity
(
    user_id Int32 NOT NULL,
    timestamp Int64 NOT NULL,
    identifier Int32 DEFAULT 0,
    duration Int32 DEFAULT 0,
    retailer_id Int32 NOT NULL,
    offbeat Bool DEFAULT false
)
ENGINE = ReplacingMergeTree(timestamp)
PARTITION BY toYYYYMM(toDateTime(timestamp))
ORDER BY (user_id, timestamp, retailer_id)
SETTINGS index_granularity = 8192;