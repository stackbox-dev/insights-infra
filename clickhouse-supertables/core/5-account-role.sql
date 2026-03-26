-- ClickHouse table for Account Role
-- Source: public.account_role

CREATE TABLE IF NOT EXISTS backbone_account_role
(
    id String DEFAULT '',
    accountId Int64 DEFAULT 0,
    nodeId Int64 DEFAULT 0,
    roleId String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    active Bool DEFAULT true,
    grantedBy Int64 DEFAULT 0,
    code String DEFAULT '',
    data String DEFAULT '{}'
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;
