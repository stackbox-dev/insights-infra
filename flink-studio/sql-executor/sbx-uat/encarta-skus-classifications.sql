-- source table
CREATE TABLE classifications (
    id VARCHAR NOT NULL,
    principal_id BIGINT NOT NULL,
    sku_id VARCHAR NOT NULL,
    type VARCHAR NOT NULL,
    `value` VARCHAR,
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    is_deleted BOOLEAN,
    PRIMARY KEY (id) NOT ENFORCED,
    WATERMARK FOR created_at AS created_at - INTERVAL '5' SECOND
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.encarta.public.classifications',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'key.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'key.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'value.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'value.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}'
);
-- destination table
CREATE TABLE skus_classifications_agg (
    sku_id VARCHAR NOT NULL,
    classifications VARCHAR NOT NULL,
    created_at TIMESTAMP(3) NOT NULL,
    updated_at TIMESTAMP(3) NOT NULL,
    PRIMARY KEY (sku_id) NOT ENFORCED,
    WATERMARK FOR created_at AS created_at - INTERVAL '5' SECOND
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.encarta.public.skus_classifications_agg',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'key.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'key.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'value.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'value.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}'
);
-- populate
-- Population script for SKU classifications table
INSERT INTO skus_classifications_agg
SELECT sc.sku_id,
    COALESCE(
        CAST(
            JSON_OBJECTAGG(KEY sc.type VALUE sc.`value`) AS STRING
        ),
        '{}'
    ) AS sku_classifications,
    MIN(sc.created_at) AS created_at,
    MAX(sc.updated_at) AS updated_at
FROM classifications sc
GROUP BY sc.sku_id;