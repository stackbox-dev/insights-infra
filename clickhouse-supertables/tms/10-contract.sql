-- ClickHouse table for Contract
-- Dimension table for Contract information
-- Source: tms.public.contract

CREATE TABLE IF NOT EXISTS tms_contract
(
    id String DEFAULT '',
    code String DEFAULT '',            
    transporter_id String DEFAULT '', 
    contract_type String DEFAULT '', 
    service_type String DEFAULT '',
    start_date DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    end_date DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    active Bool DEFAULT true,
    node_id String DEFAULT '',        
    created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(updated_at)  
PARTITION BY toYYYYMM(created_at)     
ORDER BY (id)                        
SETTINGS index_granularity = 8192;