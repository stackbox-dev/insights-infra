-- ClickHouse table for Load
-- Dimension table for Load information
-- Source: tms.public.load

CREATE TABLE IF NOT EXISTS tms_load
(
    id String DEFAULT '',                       
    principal String DEFAULT '',                 
    code String DEFAULT '',                     
    vehicle_type String DEFAULT '',              
    vehicle String DEFAULT '',                   
    driver String DEFAULT '',                    
    driver_phone String DEFAULT '',             
    dock String DEFAULT '[]',                    
    transporter String DEFAULT '',               
    container String DEFAULT '',                
    dispatch_date DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00',3), 
    plan_id String DEFAULT '',                  
    active Bool DEFAULT true,                    
    wt Float32 DEFAULT 0.0,                        
    vol Float32 DEFAULT 0.0,                      
    hu_type String DEFAULT '',                    
    hu_count Int32 DEFAULT 0,                    
    asns String DEFAULT '[]',                    
    type String DEFAULT 'OUTBOUND',              
    delivery_date DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00',3),
    delivery_no String DEFAULT '',               
    start_point String DEFAULT '',               
    end_point String DEFAULT '',                
    special_lane Bool DEFAULT false,                
    documents String DEFAULT '[]',              
    node_id String DEFAULT '',                    
    created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00',3),    
    updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00',3),   
    distance_travelled Float32 DEFAULT 0.0,     
    contract_id String DEFAULT '',               
    cost Float32 DEFAULT 0.0,                      
    invoice_id String DEFAULT '',                 
    toll_cost Float32 DEFAULT 0.0,                  
    pod String DEFAULT '[]',                     
    is_completed Bool DEFAULT false                 
)
ENGINE = ReplacingMergeTree(updated_at)         
PARTITION BY toYYYYMM(created_at)               
ORDER BY (id)                                    
SETTINGS index_granularity = 8192;