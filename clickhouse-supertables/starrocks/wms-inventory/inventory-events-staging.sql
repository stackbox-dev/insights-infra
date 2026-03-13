CREATE TABLE wms_inventory_events_staging (
    event_id STRING NOT NULL,
    quant_event_id STRING NOT NULL,
    wh_id BIGINT NULL,
    seq BIGINT NULL,
    hu_id STRING NULL,
    event_type STRING NULL,
    timestamp DATETIME NULL,
    payload STRING NULL,
    attrs STRING NULL,
    session_id STRING NULL,
    task_id STRING NULL,
    correlation_id STRING NULL,
    storage_id STRING NULL,
    outer_hu_id STRING NULL,
    effective_storage_id STRING NULL,
    sku_id STRING NULL,
    uom STRING NULL,
    bucket STRING NULL,
    batch STRING NULL,
    price STRING NULL,
    inclusion_status STRING NULL,
    locked_by_task_id STRING NULL,
    lock_mode STRING NULL,
    qty_added INT NULL,
    quant_iloc STRING NULL
)
ENGINE=OLAP
PRIMARY KEY(event_id, quant_event_id)
DISTRIBUTED BY HASH(event_id) BUCKETS 2
ORDER BY (event_id, quant_event_id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
