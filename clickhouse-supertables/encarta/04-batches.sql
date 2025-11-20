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
    packing_date DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    expiry_date DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    active Bool DEFAULT false,
    price Float64 DEFAULT 0.0,
    price_lot String DEFAULT '',
    identifier1 String DEFAULT '',
    tag1 String DEFAULT '',
    sku_code String,
    created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    __source_ts_ms Int64 DEFAULT 0
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (principal_id, sku_code, code)
SETTINGS index_granularity = 8192,
         deduplicate_merge_projection_mode = 'drop';





         -- Table Definition
CREATE TABLE "public"."batches" (
    "id" uuid NOT NULL,
    "principal_id" int8 NOT NULL,
    "sku_id" uuid,
    "code" varchar NOT NULL,
    "batch_name" varchar,
    "batch_desc" varchar,
    "source_factory" varchar,
    "case_config" int4,
    "packing_date" timestamptz,
    "expiry_date" timestamptz,
    "active" bool,
    "price" float8,
    "price_lot" varchar,
    "identifier1" varchar,
    "tag1" varchar,
    "sku_code" varchar NOT NULL,
    "created_at" timestamptz DEFAULT now(),
    "updated_at" timestamptz DEFAULT now(),
    CONSTRAINT "batches_sku_id_fkey" FOREIGN KEY ("sku_id") REFERENCES "public"."skus"("id"),
    PRIMARY KEY ("id")
);


-- Indices
CREATE UNIQUE INDEX uniq_batches ON public.batches USING btree (principal_id, sku_code, code);