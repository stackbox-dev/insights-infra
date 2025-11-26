-- ClickHouse table for Line
-- Dimension table for Line information
-- Source: tms.public.line

CREATE TABLE IF NOT EXISTS tms_lht_line
(
    id String DEFAULT '',           
    order_id String DEFAULT '',       
    sku String DEFAULT '',  
    mrp Int32 DEFAULT 0,  
    qty Int32 DEFAULT 0,   
    uom String DEFAULT 'L0',
    hu_type String DEFAULT '', 
    hu_count Int32 DEFAULT 0,    
    wt Float32 DEFAULT 0.0,    
    vol Float32 DEFAULT 0.0,       
    brand String DEFAULT '',    
    category String DEFAULT '',    
    node_id String DEFAULT '',   
    created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    cost Float32 DEFAULT 0.0,  
    cost_share Float32 DEFAULT 1.0
)
ENGINE = ReplacingMergeTree(updated_at)          
PARTITION BY toYYYYMM(created_at)               
ORDER BY (id)                                  
SETTINGS index_granularity = 8192;