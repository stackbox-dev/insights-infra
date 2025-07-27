CREATE TABLE `sbx-uat.backbone.public.node` (
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
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx-uat.backbone.public.node',
    'properties.bootstrap.servers' = 'bootstrap.sbx-kafka-cluster.asia-south1.managedkafka.sbx-stag.cloud.goog:9092',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'OAUTHBEARER',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;',
    'properties.sasl.login.callback.handler.class' = 'com.google.cloud.hosted.kafka.auth.GcpLoginCallbackHandler',
    'properties.group.id' = 'flink-backbone-public-node',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'http://cp-schema-registry.kafka:80',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'http://cp-schema-registry.kafka:80'
);
---
CREATE TABLE `sbx-uat.backbone.public.node2` (
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
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx-uat.backbone.public.node2',
    'properties.bootstrap.servers' = 'bootstrap.sbx-kafka-cluster.asia-south1.managedkafka.sbx-stag.cloud.goog:9092',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'OAUTHBEARER',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;',
    'properties.sasl.login.callback.handler.class' = 'com.google.cloud.hosted.kafka.auth.GcpLoginCallbackHandler',
    'properties.group.id' = 'flink-backbone-public-node',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'http://cp-schema-registry.kafka:80',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'http://cp-schema-registry.kafka:80'
);
--
INSERT INTO `sbx-uat.backbone.public.node2`
SELECT *
FROM `sbx-uat.backbone.public.node`;
--