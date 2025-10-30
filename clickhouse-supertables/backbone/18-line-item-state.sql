-- ClickHouse table for Line Item State
-- Source: public.line_item_state

CREATE TABLE IF NOT EXISTS backbone_line_item_state
(
    id String DEFAULT '',
    lineItemId Int32 DEFAULT 0,
    stateId Int32 DEFAULT 0,
    invoiceId Int32 DEFAULT 0,
    deliveredQuantity Int32 DEFAULT 0,
    deliveredValue Float64 DEFAULT 0.0,
    failReasons Array(String) DEFAULT [],
    images Array(String) DEFAULT [],
    active Bool DEFAULT true,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    deliveredWeight Float64 DEFAULT 0.0,
    dbUpdatedAt DateTime64(3) DEFAULT now()
)
ENGINE = ReplacingMergeTree(dbUpdatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;







-- Table Definition
CREATE TABLE "public"."line_item_state" (
    "id" uuid NOT NULL,
    "lineItemId" int4 NOT NULL,
    "stateId" int4 NOT NULL,
    "invoiceId" int4 NOT NULL,
    "deliveredQuantity" int4 NOT NULL,
    "deliveredValue" float8,
    "failReasons" _text NOT NULL DEFAULT '{}'::text[],
    "images" _text NOT NULL DEFAULT '{}'::text[],
    "active" bool NOT NULL DEFAULT true,
    "createdAt" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deliveredWeight" float8,
    PRIMARY KEY ("id")
);


-- Indices
CREATE INDEX idx_lineitemstate_stateid ON public.line_item_state USING btree ("stateId");