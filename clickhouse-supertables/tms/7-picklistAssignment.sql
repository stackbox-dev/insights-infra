-- ClickHouse table for Picklist Assignment
-- Source: public.picklistAssignment

CREATE TABLE IF NOT EXISTS tms_picklistAssignment
(
    id Int32 DEFAULT 0,
    picklistId Int32 DEFAULT 0,
    date Date DEFAULT '1970-01-01',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    active Bool DEFAULT true,
    agentId Int64 DEFAULT 0,
    vehicleId Int64 DEFAULT 0,
    assignedBy Int64 DEFAULT 0,
    secondaryDeliveryAgentIds Array(Int64) DEFAULT [],
    state String DEFAULT 'COLLECTING',
    denominations String DEFAULT '{}',
    dbUpdatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    release String DEFAULT 'tracking-assignment',
    assignedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    data String DEFAULT '{}',
    inventoryApprovedBy Int64 DEFAULT 0,
    inventoryApprovedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    paymentsApprovedBy Int64 DEFAULT 0,
    paymentsApprovedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    pdTransfer String DEFAULT '[]',
    trackingTriggeredAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    contractId String DEFAULT '',
    transporterId String DEFAULT '',
    version Int32 DEFAULT 0
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;