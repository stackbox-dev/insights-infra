-- Materialized table for SKU classifications backed by topic
CREATE TABLE `sbx-uat.encarta.public.skus_classifications_agg` (
    sku_id VARCHAR,
    classifications VARCHAR,
    PRIMARY KEY (sku_id) NOT ENFORCED
) WITH (
    'connector' = 'confluent',
    'value.format' = 'avro-registry'
);
