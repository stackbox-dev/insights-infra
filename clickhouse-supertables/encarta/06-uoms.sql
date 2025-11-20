CREATE TABLE IF NOT EXISTS encarta_uoms
(
    id String DEFAULT '',
    principal_id Int64 DEFAULT 0,
    sku_id String DEFAULT '',
    name String DEFAULT '',
    hierarchy String DEFAULT '',
    weight Float64 DEFAULT 0.0,
    volume Float64 DEFAULT 0.0,
    package_type String DEFAULT '',
    length Float64 DEFAULT 0.0,
    width Float64 DEFAULT 0.0,
    height Float64 DEFAULT 0.0,
    units Int32 DEFAULT 0,
    packing_efficiency Float64 DEFAULT 0.0,
    active Bool DEFAULT false,
    itf_code String DEFAULT '',
    created_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    updated_at DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3),
    erp_weight Float64 DEFAULT 0.0,
    erp_volume Float64 DEFAULT 0.0,
    erp_length Float64 DEFAULT 0.0,
    erp_width Float64 DEFAULT 0.0,
    erp_height Float64 DEFAULT 0.0,
    text_tag1 String DEFAULT '',
    text_tag2 String DEFAULT '',
    image String DEFAULT '',
    num_tag1 Float64 DEFAULT 0.0
)
ENGINE = ReplacingMergeTree(updated_at)
PARTITION BY toYYYYMM(created_at)
ORDER BY (id)
SETTINGS index_granularity = 8192;