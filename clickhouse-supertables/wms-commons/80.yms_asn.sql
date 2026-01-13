-- ClickHouse table for YMS ASN
-- Dimension table for yard management system advanced shipping notice
-- Source: public.yms_asn

CREATE TABLE IF NOT EXISTS wms_yms_asn
(
    whId Int64 DEFAULT 0,
    id String DEFAULT '',
    asnNo String DEFAULT '',
    dispatchDate DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    deliveryDate DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    vehicleNo String DEFAULT '',
    vehicleType String DEFAULT '',
    transporter String DEFAULT '',
    plantCode String DEFAULT '',
    tripVolume Float64 DEFAULT 0.0,
    tripTonnage Float64 DEFAULT 0.0,
    unloadingTime Int32 DEFAULT 0,
    caseCount Int32 DEFAULT 0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    deactivatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    deactivatedBy Int64 DEFAULT 0,
    groupId String DEFAULT '',
    poNos String DEFAULT '[]',  -- JSON array
    deliveryNos String DEFAULT '[]',  -- JSON array
    lrNumber String DEFAULT '',
    trailerNo String DEFAULT '',
    tripCode String DEFAULT '',
    truckLoadType String DEFAULT '',
    iloc String DEFAULT '',
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192