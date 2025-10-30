-- ClickHouse table for Odometer
-- Source: public.odometer

CREATE TABLE IF NOT EXISTS backbone_odometer
(
    id String DEFAULT '',
    assignmentId Int32 DEFAULT 0,
    state String DEFAULT '',
    reading Int32 DEFAULT 0,
    image String DEFAULT '',
    latitude Float64 DEFAULT 0.0,
    longitude Float64 DEFAULT 0.0,
    geoAccuracy Float64 DEFAULT 0.0,
    editedBy Int64 DEFAULT 0,
    active Bool DEFAULT true,
    createdAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updatedAt DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    detectedReading Int32 DEFAULT 0,
    dbUpdatedAt DateTime64(3) DEFAULT now()
)
ENGINE = ReplacingMergeTree(dbUpdatedAt)
PARTITION BY toYYYYMM(createdAt)
ORDER BY (assignmentId, state)
SETTINGS index_granularity = 8192;







-- Table Definition
CREATE TABLE "public"."odometer" (
    "id" uuid NOT NULL,
    "assignmentId" int4 NOT NULL,
    "state" text NOT NULL,
    "reading" int4 NOT NULL,
    "image" text NOT NULL,
    "latitude" float8,
    "longitude" float8,
    "geoAccuracy" float8,
    "editedBy" int8 NOT NULL,
    "active" bool NOT NULL DEFAULT true,
    "createdAt" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "detectedReading" int4,
    PRIMARY KEY ("id")
);


-- Indices
CREATE UNIQUE INDEX odometer_assignmentid_state ON public.odometer USING btree ("assignmentId", state) WHERE (active = true);