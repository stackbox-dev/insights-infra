-- ClickHouse table for Invoice State
-- Dimension table for Invoice State information
-- Source: tms.public.invoice_state

CREATE TABLE IF NOT EXISTS tms_lht_invoice_state
(
    id String DEFAULT '',                     
    invoice_id String DEFAULT '',            
    prev_state_id String DEFAULT '',          
    state String DEFAULT 'CREATED',           
    blocked Bool DEFAULT false,                  
    active Bool DEFAULT true,                   
    deleted Bool DEFAULT false,                  
    user_id String DEFAULT '',                
    node_id String DEFAULT '',                
    created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3) 
)
ENGINE = ReplacingMergeTree(updated_at)      
PARTITION BY toYYYYMM(created_at)           
ORDER BY (id)                                
SETTINGS index_granularity = 8192;




