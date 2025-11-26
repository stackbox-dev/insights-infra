-- ClickHouse table for VehicleType
-- Source: public.vehicleType

CREATE TABLE IF NOT EXISTS tms_vehicleType
(
    id Int32 DEFAULT 0,
    profileId Int32 DEFAULT 0,
    name String DEFAULT '',
    fixedCostTime Float64 DEFAULT 0.0,
    maxDropPoints Int32 DEFAULT 0,
    maxTripTime Float64 DEFAULT 0.0,
    maxVolume Float64 DEFAULT 0.0,
    maxWeight Float64 DEFAULT 0.0,
    vehicleCount Int32 DEFAULT 0,
    avgSpeed Float64 DEFAULT 0.0,
    volumeLimitRatio Float64 DEFAULT 1.0,
    maxDistance Float64 DEFAULT 0.0,
    serviceTime Float64 DEFAULT 0.0,
    loadingTime Float64 DEFAULT 0.0,
    isSplitCompatible Bool DEFAULT true,
    maxValue Float64 DEFAULT 0.0,
    fixedCostThreshold Float64 DEFAULT 0.0,
    variableCost Float64 DEFAULT 0.0,
    fixedCostMoney Float64 DEFAULT 0.0,
    retailerSalesMinValue Float64 DEFAULT 0.0,
    retailerSalesMaxValue Float64 DEFAULT 0.0
)
ENGINE = ReplacingMergeTree()
ORDER BY (id)
SETTINGS index_granularity = 8192;