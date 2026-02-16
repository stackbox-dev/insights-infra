-- ClickHouse table for User Account
-- Source: public.user_account

CREATE TABLE IF NOT EXISTS backbone_user_account
(
    id Int64 DEFAULT 0,
    loginId String DEFAULT '',
    name String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    active Bool DEFAULT true,
    phone String DEFAULT '',
    email String DEFAULT '',
    apiKey String DEFAULT '',
    nodeId Int64 DEFAULT 0,
    createdBy Int64 DEFAULT 0,
    updatedBy Int64 DEFAULT 0
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;