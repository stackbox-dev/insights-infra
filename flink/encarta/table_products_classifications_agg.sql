-- Materialized table for product classifications backed by topic
CREATE TABLE `sbx-uat.encarta.public.products_classifications_agg` (
    product_id VARCHAR NOT NULL,
    product_classifications VARCHAR NOT NULL,
    created_at TIMESTAMP_LTZ(3) NOT NULL,
    updated_at TIMESTAMP_LTZ(3) NOT NULL,
    PRIMARY KEY (product_id) NOT ENFORCED,
    WATERMARK FOR created_at AS created_at - INTERVAL '5' SECOND
) WITH (
    'connector' = 'confluent',
    'value.format' = 'avro-registry'
);