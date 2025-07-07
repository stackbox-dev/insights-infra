-- Materialized table for product classifications backed by topic
CREATE TABLE `sbx-uat.encarta.public.products_classifications_agg` (
    product_id VARCHAR NOT NULL,
    product_classifications VARCHAR NOT NULL,
    updated_at TIMESTAMP_LTZ(3) NOT NULL,
    PRIMARY KEY (product_id) NOT ENFORCED,
    WATERMARK FOR updated_at AS updated_at - INTERVAL '5' SECONDS
) WITH (
    'connector' = 'confluent',
    'value.format' = 'avro-registry'
);
