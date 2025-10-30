-- ClickHouse table for Invoice Extras
-- Source: public.invoiceExtras

CREATE TABLE IF NOT EXISTS backbone_invoiceExtras
(
    invoiceId Int32 DEFAULT 0,
    state String DEFAULT '',
    stateId Int32 DEFAULT 0,
    plannedDate String DEFAULT '',
    nodeId Int64 DEFAULT 0
)
ENGINE = ReplacingMergeTree()
PARTITION BY toYYYYMM(now())
ORDER BY (invoiceId, nodeId)
SETTINGS index_granularity = 8192;








-- Table Definition
CREATE TABLE "public"."invoiceExtras" (
    "invoiceId" int4 NOT NULL,
    "state" text,
    "stateId" int4,
    "plannedDate" text,
    "nodeId" int8,
    CONSTRAINT "invoiceextras_invoiceid_foreign" FOREIGN KEY ("invoiceId") REFERENCES "public"."invoice"("id")
);


-- Indices
CREATE INDEX idx_invoiceextras_planneddate ON public."invoiceExtras" USING btree ("plannedDate");
CREATE UNIQUE INDEX con_invoiceextras_invoice_node ON public."invoiceExtras" USING btree ("invoiceId", "nodeId");
CREATE INDEX idx_invoiceextras_nodeid_state ON public."invoiceExtras" USING btree ("nodeId", state) WHERE ((state = 'HOLD'::text) OR (state = 'RETRY'::text));