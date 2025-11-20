-- ClickHouse table for Backbone External Vehicle Events  
-- Source: backbone.public.extvehicleevents

CREATE TABLE IF NOT EXISTS backbone_extvehicleevents
(
    id Int64,
    vehicleno String DEFAULT '',
    vehicleid Nullable(Int64),
    eventtype String DEFAULT '',
    eventtime DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    version Int32 DEFAULT 1,
    createdat DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedat DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    status String DEFAULT '',
    remarks String DEFAULT '',
    picklistid Nullable(Int64),
    planid Nullable(Int64),
    transporterid String DEFAULT '',
    tripcode String DEFAULT '',
    vehicleeventid String DEFAULT ''
)
ENGINE = ReplacingMergeTree(updatedat)
PARTITION BY toYYYYMM(createdat)
ORDER BY (id, createdat)
SETTINGS index_granularity = 8192;




CREATE TABLE IF NOT EXISTS backbone_extvehicleevents
(
    id Int64 DEFAULT 0,
    vehicleno String DEFAULT '',
    vehicleid Int64 DEFAULT 0,
    eventtype String DEFAULT '',
    eventtime DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    version Int32 DEFAULT 1,
    createdat DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedat DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    status String DEFAULT '',
    remarks String DEFAULT '',
    picklistid Int64 DEFAULT 0,
    planid Int64 DEFAULT 0,
    transporterid String DEFAULT '',
    tripcode String DEFAULT '',
    vehicleeventid String DEFAULT ''
)
ENGINE = ReplacingMergeTree(updatedat)
PARTITION BY toYYYYMM(createdat)
ORDER BY (id, createdat)
SETTINGS index_granularity = 8192;