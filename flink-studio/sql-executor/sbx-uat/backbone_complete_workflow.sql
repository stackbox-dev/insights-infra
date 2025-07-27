-- Complete backbone public node workflow: Create, Test, and Query
-- First create the table
CREATE TABLE `sbx-uat_backbone_public_node` (
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
    'properties.bootstrap.servers' = 'bootstrap.sbx-kafka-cluster.asia-south1.managedkafka.sbx-stag.cloud.goog:9092',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'OAUTHBEARER',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;',
    'properties.sasl.login.callback.handler.class' = 'com.google.cloud.hosted.kafka.auth.GcpLoginCallbackHandler',
    'properties.group.id' = 'flink-backbone-public-node',
    'scan.startup.mode' = 'earliest-offset',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'http://cp-schema-registry.kafka:80'
);
-- Test query to describe the node table structure
-- DESCRIBE `sbx-uat_backbone_public_node`;
-- Query the table data
SELECT *
FROM `sbx-uat_backbone_public_node`
LIMIT 100;