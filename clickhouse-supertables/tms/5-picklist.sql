-- ClickHouse Table: picklist
-- Source: postgres.public.picklist

CREATE TABLE IF NOT EXISTS tms_picklist
(
    id Int64 DEFAULT 0,
    planId Int32 DEFAULT 0,
    `index` Int32 DEFAULT 0,
    active Bool DEFAULT true,
    tripTime Int32 DEFAULT 0,
    serviceTime Int32 DEFAULT 0,
    tripDistance Int32 DEFAULT 0,
    vehicleTypeId Int32 DEFAULT 0,
    path String DEFAULT '',
    startTime Int32 DEFAULT 0,
    name String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    dispatchedToXdock Bool DEFAULT false,
    wmsSortingSessionId String DEFAULT '',
    vehicleIndex Int32 DEFAULT 0,
    vehicleTripIndex Int32 DEFAULT 0,
    wmsPickingSessionId String DEFAULT '',
    wmsPacked Bool DEFAULT false,
    wmsClReturnsSessionId String DEFAULT '',
    wmsClReturnsDoneAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    wmsBreakbulkState String DEFAULT '',
    wmsVehicleSortingSessionId String DEFAULT '',
    transporterCode String DEFAULT '',
    externalId String DEFAULT '',
    remarks Array(String) DEFAULT [],
    tripRemarks Array(String) DEFAULT []
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;