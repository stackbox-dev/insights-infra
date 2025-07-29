CREATE TABLE x_nodes (
    id BIGINT,
    parentId BIGINT,
    `group` STRING,
    code STRING,
    name STRING,
    type STRING,
    data STRING,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    active BOOLEAN,
    hasLocations BOOLEAN,
    platform STRING,
    is_deleted BOOLEAN,
    proc_time AS PROCTIME(),
    event_time AS CASE
        WHEN updatedAt > createdAt THEN updatedAt
        ELSE createdAt
    END,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'sbx_uat.backbone.public.node',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'scan.startup.mode' = 'earliest-offset',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'value.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'value.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}'
);
SELECT *
FROM x_nodes
LIMIT 100;