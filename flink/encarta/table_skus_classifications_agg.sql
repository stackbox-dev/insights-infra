-- Materialized table for SKU classifications backed by topic
CREATE TABLE `sbx-uat.encarta.public.skus_classifications_agg` (
    sku_id VARCHAR NOT NULL,
    classifications VARCHAR NOT NULL,
    created_at TIMESTAMP_LTZ(3) NOT NULL,
    updated_at TIMESTAMP_LTZ(3) NOT NULL,
    PRIMARY KEY (sku_id) NOT ENFORCED,
    WATERMARK FOR created_at AS created_at - INTERVAL '5' SECOND
) WITH (
    'connector' = 'confluent',
    'value.format' = 'avro-registry'
);