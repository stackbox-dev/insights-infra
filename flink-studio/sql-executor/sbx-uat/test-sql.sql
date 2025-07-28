-- source table
CREATE TABLE `sbx-uat.encarta.public.product_classifications` (
    id VARCHAR NOT NULL,
    principal_id BIGINT NOT NULL,
    product_id VARCHAR NOT NULL,
    type VARCHAR NOT NULL,
    `value` VARCHAR,
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    is_deleted BOOLEAN,
    PRIMARY KEY (id) NOT ENFORCED,
    WATERMARK FOR created_at AS created_at - INTERVAL '5' SECOND
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx-uat.encarta.public.product_classifications',
    'properties.bootstrap.servers' = 'bootstrap.sbx-kafka-cluster.asia-south1.managedkafka.sbx-stag.cloud.goog:9092',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'OAUTHBEARER',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;',
    'properties.sasl.login.callback.handler.class' = 'com.google.cloud.hosted.kafka.auth.GcpLoginCallbackHandler',
    'properties.auto.offset.reset' = 'earliest',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'http://cp-schema-registry.kafka',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'http://cp-schema-registry.kafka'
);
-- destination table
CREATE TABLE `sbx-uat.encarta.public.products_classifications_agg` (
    product_id VARCHAR NOT NULL,
    product_classifications VARCHAR NOT NULL,
    created_at TIMESTAMP(3) NOT NULL,
    updated_at TIMESTAMP(3) NOT NULL,
    PRIMARY KEY (product_id) NOT ENFORCED,
    WATERMARK FOR created_at AS created_at - INTERVAL '5' SECOND
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx-uat.encarta.public.products_classifications_agg',
    'properties.bootstrap.servers' = 'bootstrap.sbx-kafka-cluster.asia-south1.managedkafka.sbx-stag.cloud.goog:9092',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'OAUTHBEARER',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;',
    'properties.sasl.login.callback.handler.class' = 'com.google.cloud.hosted.kafka.auth.GcpLoginCallbackHandler',
    'properties.transaction.id.prefix' = 'encarta-products-classifications-agg',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'http://cp-schema-registry.kafka',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'http://cp-schema-registry.kafka'
);
-- populate
-- Population script for product classifications table
SELECT pc.product_id,
    COALESCE(
        CAST(
            JSON_OBJECTAGG(KEY pc.type VALUE pc.`value`) AS STRING
        ),
        '{}'
    ) AS product_classifications,
    MIN(pc.created_at) AS created_at,
    MAX(pc.updated_at) AS updated_at
FROM `sbx-uat.encarta.public.product_classifications` pc
GROUP BY pc.product_id;