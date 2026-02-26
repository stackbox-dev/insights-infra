-- ClickHouse table for WMS Worker MHE Mapping
-- Dimension table for WMS Worker MHE Mapping information
-- Source: digitaldc_prod.wms.public.worker_mhe_mapping

CREATE TABLE IF NOT EXISTS wms_worker_mhe_mapping
(
    id String DEFAULT '',
    whId Int64 DEFAULT 0,
    workerId String DEFAULT '',
    mheId String DEFAULT '',
    mheCode String DEFAULT '',
    deviceSessionId String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    deactivatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
)
ENGINE = ReplacingMergeTree(updatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;