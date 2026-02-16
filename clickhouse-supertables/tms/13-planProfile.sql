-- ClickHouse table for Plan Profile
-- Source: public.planProfile

CREATE TABLE IF NOT EXISTS tms_planProfile
(
    id Int32 DEFAULT 0,
    active Bool DEFAULT false,
    branchId Int64 DEFAULT 0,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    name String DEFAULT '',
    default Bool DEFAULT false,
    allSalesmen Bool DEFAULT false,
    serviceTimeModel String DEFAULT '',
    salesmanIds Array(Int64) DEFAULT [],
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    serviceTimeData String DEFAULT '{}',
    static Bool DEFAULT false,
    autoFreeze Bool DEFAULT false,
    data String DEFAULT '{}',
    allowIncremental Bool DEFAULT false,
    serviceTypes Array(String) DEFAULT [],
    exclusiveZones String DEFAULT '{}',
    routingProfile String DEFAULT 'distance',
    autoLearning Bool DEFAULT false,
    isDummy Bool DEFAULT false,
    planningTypes Array(String) DEFAULT [],
    allChannels Bool DEFAULT true,
    channels Array(String) DEFAULT []
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;