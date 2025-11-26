-- ClickHouse table for Retailer
-- Dimension table for Retailer information
-- Source: backbone.public.retailer

CREATE TABLE IF NOT EXISTS tms_retailer
(
   id Int32 DEFAULT 0,
   createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
   updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
   version Int32 DEFAULT 0,
   branchId Int64 DEFAULT 0,
   code String DEFAULT '',
   active bool DEFAULT true,
   name String DEFAULT '',
   allowReedit bool DEFAULT false,
   latitude Float64 DEFAULT 0.0,
   longitude Float64 DEFAULT 0.0,
   geoAccuracy Float64 DEFAULT 0.0,
   mappedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
   mappedBy Int64 DEFAULT 0,
   phone String DEFAULT '',
   phoneVerified bool DEFAULT false,
   isNew bool DEFAULT false,
   isAssigned bool DEFAULT false,
   channel String DEFAULT '',
   images Array(String),
   extraFields String DEFAULT '',
   noDeliveryWindow String DEFAULT '',
   editedBy Int64 DEFAULT 0,
   deliveryWindow String DEFAULT '',
   classification String DEFAULT '',
   deliveryWindowWeekly String DEFAULT '',
   operatingWindow String DEFAULT '',
   incompatibleVehicleTypes Array(String) DEFAULT [],
   universeId String DEFAULT '',
   locationVerified Bool DEFAULT false,
   partnerCode String DEFAULT '',
   parentId Int32 DEFAULT 0,
   processedForDuplicates Bool DEFAULT false,
   destination String DEFAULT ''
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;