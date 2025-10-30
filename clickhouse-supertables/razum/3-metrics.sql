-- ClickHouse table for Metrics
-- Source: public.metrics
CREATE TABLE IF NOT EXISTS razum_metrics
(
    `index` Int64 DEFAULT 0,
    day_stamp Int32 DEFAULT 0,
    user_id Int32 DEFAULT 0,
    identifier Int32 DEFAULT 0,
    invalid Bool DEFAULT false,
    invalidated_at Int64 DEFAULT 0,
    identifier_count Int32 DEFAULT 0,
    timestamp Int64 DEFAULT 0,
    data String DEFAULT '{}',
    dbUpdatedAt DateTime64(3) DEFAULT now()
)
ENGINE = ReplacingMergeTree(dbUpdatedAt)
ORDER BY (index)
SETTINGS index_granularity = 8192;


CREATE TABLE IF NOT EXISTS razum_metrics
(
    `index` Int64 DEFAULT 0,
    day_stamp Int32,
    user_id Int32,
    identifier Int32,
    invalid Bool,
    invalidated_at Int64,
    identifier_count Int32,
    timestamp Int64,
    data String,
    dbUpdatedAt DateTime64(3) DEFAULT now()
)
ENGINE = ReplacingMergeTree(dbUpdatedAt)
ORDER BY (index)
SETTINGS index_granularity = 8192;











-- Sequence and defined type
CREATE SEQUENCE IF NOT EXISTS metrics_index_seq;

-- Table Definition
CREATE TABLE "public"."metrics" (
    "index" int8 NOT NULL DEFAULT nextval('metrics_index_seq'::regclass),
    "day_stamp" int4,
    "user_id" int4,
    "identifier" int4,
    "invalid" bool,
    "invalidated_at" int8,
    "identifier_count" int4,
    "timestamp" int8,
    "data" json,
    PRIMARY KEY ("index")
);


-- Indices
CREATE UNIQUE INDEX only_one_valid_row_metrics ON public.metrics USING btree (day_stamp, user_id, identifier, invalid) WHERE (NOT invalid);