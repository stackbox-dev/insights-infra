-- ClickHouse table for Invoice
-- Source: tms.public.invoice (Postgres)

CREATE TABLE IF NOT EXISTS tms_invoice
(
    sessionCreatedAt DEFAULT toDateTime64('1970-01-01 00:00:00', 3),     
    whId Int64 DEFAULT 0,                              
    sessionId String DEFAULT '', 
    id String DEFAULT '', 
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    bbId String DEFAULT '',   
    code String DEFAULT '',               
    lmTripId String DEFAULT '',                   
    mmTripId String DEFAULT '',               
    retailerId String DEFAULT '',                    
    retailerCode String DEFAULT '',           
    distributorId String DEFAULT '',                   
    lmTripIndex Int32 DEFAULT 0,                      
    retailerName String DEFAULT '',                  
    retailerChannel String DEFAULT '',               
    salesmanId String DEFAULT '',                     
    salesmanCode String DEFAULT '',                   
    priority Int32 DEFAULT 0,                        
    attrs String DEFAULT '{}',                          
    deliveryDate Date DEFAULT toDate('1970-01-01'),    
    xdock String DEFAULT ''                          
)
ENGINE = ReplacingMergeTree(createdAt)
PARTITION BY toYYYYMM(sessionCreatedAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;