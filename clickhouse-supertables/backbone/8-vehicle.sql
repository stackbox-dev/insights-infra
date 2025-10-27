-- ClickHouse table for Vehicle
-- Source: public.vehicle

CREATE TABLE IF NOT EXISTS backbone_vehicle
(
    id Int64 DEFAULT 0,
    nodeId Int64 DEFAULT 0,
    vehicleNo String DEFAULT '',
    vehicleType String DEFAULT '',
    name String DEFAULT '',
    carrierName String DEFAULT '',
    city String DEFAULT '',
    contractType String DEFAULT '',
    vehicleWidth Float64 DEFAULT 0.0,
    vehicleHeight Float64 DEFAULT 0.0,
    vehicleLength Float64 DEFAULT 0.0,
    maxWeight Float64 DEFAULT 0.0,
    maxCases Float64 DEFAULT 0.0,
    maxAllocation Float64 DEFAULT 0.0,
    startingLatitude Float64 DEFAULT 0.0,
    startingLongitude Float64 DEFAULT 0.0,
    endingLatitude Float64 DEFAULT 0.0,
    endingLongitude Float64 DEFAULT 0.0,
    active Bool DEFAULT true,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    phone String DEFAULT '',
    insuranceExpiration Date DEFAULT '1970-01-01',
    insuranceCertificate String DEFAULT '',
    registrationExpiration Date DEFAULT '1970-01-01',
    registrationCertificate String DEFAULT '',
    pollutionExpiration Date DEFAULT '1970-01-01',
    pollutionCertificate String DEFAULT '',
    licenseExpiration Date DEFAULT '1970-01-01',
    licenseCertificate String DEFAULT '',
    transporterCode String DEFAULT '',
    transporterName String DEFAULT '',
    loadType String DEFAULT '',
    fleetType String DEFAULT ''
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;