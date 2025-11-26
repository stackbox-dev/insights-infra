-- ClickHouse table for Contract Line
-- Dimension table for Contract Line information
-- Source: tms.public.contract_line

CREATE TABLE IF NOT EXISTS tms_lht_contract_line
(
    id String DEFAULT '',
    contract_id String DEFAULT '',
    vehicle_type String DEFAULT '',
    end_location String DEFAULT '',
    rate Float32 DEFAULT 0.0,
    fixed_cost Float32 DEFAULT 0.0,
    product_type String DEFAULT '',
    loading_charges Float32 DEFAULT 0.0,
    unloading_charges Float32 DEFAULT 0.0,
    min_billing_per_load Float32 DEFAULT 0.0,
    currency String DEFAULT 'INR',
    active Bool DEFAULT true,
    created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    manpower_charges Float32 DEFAULT 0.0
)
ENGINE = ReplacingMergeTree(updated_at)  
PARTITION BY toYYYYMM(created_at)
ORDER BY (id)
SETTINGS index_granularity = 8192;