-- ClickHouse table for InvoiceState
-- Source: public.invoiceState

CREATE TABLE IF NOT EXISTS backbone_invoiceState
(
    id Int32 DEFAULT 0,
    invoiceId Int32 DEFAULT 0,
    editedBy Int64 DEFAULT 0,
    srnValue Float64 DEFAULT 0.0,
    planId Int32 DEFAULT 0,
    state String DEFAULT '',
    stateMessage String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    active Bool DEFAULT true,
    retryInvoiceStateId Int32 DEFAULT 0,
    lineItemStates String DEFAULT '{}',
    damageReturn Float64 DEFAULT 0.0,
    invoiceUploadId Int32 DEFAULT 0,
    outstanding Float64 DEFAULT 0.0,
    dbUpdatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    collectedBy Int64 DEFAULT 0,
    picklistId Int32 DEFAULT 0,
    assignmentId Int32 DEFAULT 0,
    images Array(String) DEFAULT [],
    pod String DEFAULT '{}',
    agentAction String DEFAULT '',
    tripInvoiceId String DEFAULT '',
    planTripInvoiceId String DEFAULT '',
    nodeId Int64 DEFAULT 0,
    wmsSortingSessionId String DEFAULT '',
    messages String DEFAULT '[]',
    isNoLocationAcknowledged Bool DEFAULT false
)
ENGINE = ReplacingMergeTree(dbUpdatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;