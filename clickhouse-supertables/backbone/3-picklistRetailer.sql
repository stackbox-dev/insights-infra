-- ClickHouse table for picklistRetailer
-- Dimension table for Picklist Retailer information
-- Source: backbone.public.picklistRetailer

CREATE TABLE IF NOT EXISTS backbone_picklistRetailer
(
   id Int32,
   picklistId Int32 DEFAULT 0,
   retailerId Int32 DEFAULT 0,
   `index` Int32 DEFAULT 0,
   active bool DEFAULT true,
   nodeId Int64 DEFAULT 0,
   sales Float64 DEFAULT 0.0,
   volume Float64 DEFAULT 0.0,
   `weight` Float64 DEFAULT 0.0,
   serviceTime Float64 DEFAULT 0.0,
   node_retailer String DEFAULT '',
   createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
   updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;


