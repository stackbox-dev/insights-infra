CREATE TABLE nodes (
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
    'topic' = 'sbx-uat.backbone.public.node',
    'properties.bootstrap.servers' = '${AIVEN_KAFKA_BOOTSTRAP_SERVERS}',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-256',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${AIVEN_KAFKA_USERNAME}" password="${AIVEN_KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.truststore.type' = 'JKS',
    'properties.group.id' = 'flink-backbone-public-node',
    'scan.startup.mode' = 'earliest-offset',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = '${AIVEN_SCHEMA_REGISTRY_URL}'
);
SELECT *
FROM nodes
LIMIT 100;