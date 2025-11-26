-- ClickHouse table for Invoice Line
-- Source: tms.public.invoice_line (Postgres)

CREATE TABLE IF NOT EXISTS tms_lht_invoice_line
(
    id String DEFAULT '',                    
    invoice_id String DEFAULT '',            
    load_id String DEFAULT '',                
    is_adhoc Bool DEFAULT false,               
    activity String DEFAULT '',               
    description String DEFAULT '',           
    cost Float32 DEFAULT 0,                   
    completed_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00',3), 
    node_id String DEFAULT '',                
    created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00',3), 
    updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00',3), 
    activity_id String DEFAULT ''
)
ENGINE = ReplacingMergeTree(updated_at)
PARTITION BY toYYYYMM(created_at)                  
ORDER BY (id)                               
SETTINGS index_granularity = 8192;




