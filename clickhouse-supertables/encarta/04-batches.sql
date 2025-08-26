-- Batches table for Encarta
-- Sourced from Kafka topic: ${KAFKA_ENV}.encarta.public.batches

CREATE TABLE IF NOT EXISTS encarta_batches
(
    id String,
    principal_id Int64,
    sku_id String DEFAULT '',
    code String,
    batch_name String DEFAULT '',
    batch_desc String DEFAULT '',
    source_factory String DEFAULT '',
    case_config Int32 DEFAULT 0,
    packing_date DateTime64(3) DEFAULT toDateTime64(0, 3),
    expiry_date DateTime64(3) DEFAULT toDateTime64(0, 3),
    active Boolean DEFAULT false,
    price Float64 DEFAULT 0.0,
    price_lot String DEFAULT '',
    identifier1 String DEFAULT '',
    tag1 String DEFAULT '',
    sku_code String,
    created_at DateTime64(3) DEFAULT toDateTime64(0, 3),
    updated_at DateTime64(3) DEFAULT toDateTime64(0, 3),
    __source_ts_ms Int64 DEFAULT 0
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (principal_id, sku_code, code)
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop';