-- Materialized table for product classifications backed by topic
CREATE TABLE `sbx-uat.encarta.public.products_classifications_agg` (
    product_id VARCHAR,
    product_classifications VARCHAR,
    PRIMARY KEY (product_id) NOT ENFORCED
) WITH (
    'connector' = 'confluent',
    'value.format' = 'avro-registry'
);
