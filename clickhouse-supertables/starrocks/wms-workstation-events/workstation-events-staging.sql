CREATE TABLE wms_workstation_events_staging (
    event_type STRING NOT NULL,
    event_source_id STRING NOT NULL,
    event_timestamp DATETIME NOT NULL,
    wh_id BIGINT NULL,
    created_at DATETIME NULL,
    sku_id STRING NULL,
    hu_id STRING NULL,
    hu_code STRING NULL,
    batch_id STRING NULL,
    user_id STRING NULL,
    task_id STRING NULL,
    session_id STRING NULL,
    bin_id STRING NULL,
    primary_quantity BIGINT NULL,
    secondary_quantity BIGINT NULL,
    tertiary_quantity BIGINT NULL,
    price STRING NULL,
    status_or_bucket STRING NULL,
    reason STRING NULL,
    sub_reason STRING NULL,
    deactivated_at DATETIME NULL
)
ENGINE=OLAP
PRIMARY KEY(event_type, event_source_id, event_timestamp)
PARTITION BY date_trunc('MONTH', event_timestamp)
DISTRIBUTED BY HASH(event_source_id) BUCKETS 2
ORDER BY (wh_id, event_timestamp)
PROPERTIES (
    "compression" = "ZSTD",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2",
    "partition_live_number" = "90"
);
