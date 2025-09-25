-- Producst table for Encarta
-- Sourced from Kafka topic: ${KAFKA_ENV}.encarta.public.products



CREATE TABLE IF NOT EXISTS encarta_products
(
    id String,
    principal_id Int64,
    code String,
    name String DEFAULT '',
    description String DEFAULT '',
    sub_category_id String,
    sub_brand_id String,
    dangerous Boolean DEFAULT false,
    spillable Boolean DEFAULT false,
    frozen Boolean DEFAULT false,
    vegetarian Boolean DEFAULT false,
    dirty Boolean DEFAULT false,
    origin_country String DEFAULT '',
    hsn_code String DEFAULT '',
    active Boolean DEFAULT false,
    case_configuration Int32 DEFAULT 0,
    min_quantity Int32 DEFAULT 0,
    max_quantity Int32 DEFAULT 0,
    order_lot Int32 DEFAULT 0,
    created_at DateTime64(3) DEFAULT toDateTime64(0, 3),
    updated_at DateTime64(3) DEFAULT toDateTime64(0, 3),
    taint String DEFAULT '',
    text_tag1 String DEFAULT '',
    text_tag2 String DEFAULT '',
    num_tag1 Int32 DEFAULT 0,
    num_tag2 Int32 DEFAULT 0,
    product_classifications String DEFAULT '',
    __source_ts_ms Int64 DEFAULT 0
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (principal_id, code)
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop';