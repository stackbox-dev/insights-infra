-- ClickHouse table for WMS Inbound ASN Line Items
-- Dimension table for ASN line item information
-- Source: samadhan_prod.wms.public.inb_asn_lineitem

CREATE TABLE IF NOT EXISTS wms_inb_asn_lineitem
(
    id String,
    whId Int64 DEFAULT 0,
    asnId String,
    asnNo String DEFAULT '',
    vehicleNo String DEFAULT '',
    poNo String DEFAULT '',
    shipmentDate Date DEFAULT toDate('1970-01-01'),
    skuId String,
    uom String DEFAULT '',
    batch String DEFAULT '',
    price String DEFAULT '',
    qty Int32 DEFAULT 0,
    vendor String DEFAULT '',
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    deliveryNo String DEFAULT '',
    priority Int32 DEFAULT 0,
    lineCode String DEFAULT '',
    extraFields String DEFAULT '{}',
    bucket String DEFAULT '',
    active Bool DEFAULT true,
    asnType String DEFAULT '',
    huWeight Float64 DEFAULT 0.0,
    huNumber String DEFAULT '',
    huKind String DEFAULT '',
    huCode String DEFAULT '',
    vehicleType String DEFAULT '',
    transporterCode String DEFAULT ''
)
ENGINE = ReplacingMergeTree(createdAt)
ORDER BY (id)
SETTINGS index_granularity = 8192;





-- Table Definition
CREATE TABLE "public"."inb_asn_lineitem" (
    "id" uuid NOT NULL,
    "whId" int8 NOT NULL,
    "asnId" uuid NOT NULL,
    "asnNo" text NOT NULL,
    "vehicleNo" text,
    "poNo" text NOT NULL,
    "shipmentDate" date NOT NULL,
    "skuId" uuid NOT NULL,
    "uom" text NOT NULL,
    "batch" text NOT NULL,
    "price" text NOT NULL,
    "qty" int4 NOT NULL,
    "vendor" text NOT NULL,
    "createdAt" timestamptz NOT NULL DEFAULT now(),
    "deliveryNo" text,
    "priority" int4,
    "lineCode" text,
    "extraFields" jsonb NOT NULL DEFAULT '{}'::jsonb,
    "bucket" text,
    "active" bool DEFAULT true,
    "asnType" text NOT NULL DEFAULT ''::text,
    "huWeight" float8,
    "huNumber" text,
    "huKind" text,
    "huCode" text,
    "vehicleType" text,
    "transporterCode" text,
    PRIMARY KEY ("id")
);


-- Indices
CREATE INDEX inb_asn_lineitem_asn_idx ON public.inb_asn_lineitem USING btree ("whId", "asnId");
CREATE INDEX idx_inb_asn_lineitem_whid_pono ON public.inb_asn_lineitem USING btree ("whId", "poNo");