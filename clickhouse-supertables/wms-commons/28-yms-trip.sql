-- ClickHouse table for WMS YMS Trips
-- Dimension table for YMS Trips information
-- Source: samadhan_prod.wms.public.yms_trip

CREATE TABLE IF NOT EXISTS wms_yms_trip
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '',
    tripCode String DEFAULT '',
    retailerCodes String DEFAULT [],
    dispatchDate DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    transporter String DEFAULT '',
    vehicleType String DEFAULT '',
    vehicleNo String DEFAULT '',
    tripVolume Float64 DEFAULT 0.0,
    tripTonnage Float64 DEFAULT 0.0,
    tripDistance Float64 DEFAULT 0.0,
    earliestExitTime DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    latestExitTime DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    loadingTime Int32 DEFAULT 0,
    caseCount Int32 DEFAULT 0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    deactivatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    deactivatedBy Int64 DEFAULT 0,
    lrNumber String DEFAULT '',
    trailerNo String DEFAULT '',
    truckLoadType String DEFAULT '',
    retailerChannel String DEFAULT '',
    retailerName String DEFAULT '',
    orderType String DEFAULT '',
    priority String DEFAULT '',
    sessionKind String DEFAULT '',
    dockdoorId String DEFAULT '',
    dockdoorCode String DEFAULT ''
)
ENGINE = ReplacingMergeTree(dispatchDate)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;