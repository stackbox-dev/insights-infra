SET 'pipeline.name' = 'WMS Trip Relation Rekey';
SET 'table.exec.sink.not-null-enforcer' = 'drop';
SET 'parallelism.default' = '1';
-- Performance optimizations
SET 'taskmanager.memory.managed.fraction' = '0.8';
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '1s';
SET 'table.exec.mini-batch.size' = '5000';
SET 'execution.checkpointing.interval' = '600000';
SET 'execution.checkpointing.timeout' = '1800000';
SET 'state.backend.incremental' = 'true';
SET 'state.backend.rocksdb.compression.type' = 'LZ4';
-- Source Table: trip_relation - read as regular Kafka (not upsert) to allow rekeying
CREATE TABLE trip_relation_source (
    whId BIGINT,
    id STRING,
    sessionId STRING,
    xdock STRING,
    parentTripId STRING,
    childTripId STRING,
    createdAt STRING,
    -- ZonedTimestamp from Debezium
    `__op` STRING,
    `__source_ts_ms` BIGINT,
    `__source_snapshot` STRING,
    `event_time` AS COALESCE(
        TO_TIMESTAMP_LTZ(`__source_ts_ms`, 3),
        TIMESTAMP '1970-01-01 00:00:00'
    ),
    WATERMARK FOR `event_time` AS `event_time` - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'sbx_uat.wms.public.trip_relation',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.group.id' = 'flink-wms-trip-relation-rekey',
    -- Security settings
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    -- Schema registry - only need value format for regular Kafka
    'format' = 'avro-confluent',
    'avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'properties.auto.offset.reset' = 'earliest',
    'scan.startup.mode' = 'earliest-offset'
);
-- Sink Table: trip_relation rekeyed with composite key (sessionId, childTripId)
CREATE TABLE trip_relation_rekeyed (
    whId BIGINT,
    id STRING,
    sessionId STRING NOT NULL,
    xdock STRING,
    parentTripId STRING,
    childTripId STRING NOT NULL,
    createdAt STRING,
    -- ZonedTimestamp from Debezium
    `__op` STRING,
    `__source_ts_ms` BIGINT,
    `__source_snapshot` STRING,
    `event_time` TIMESTAMP(3) NOT NULL,
    WATERMARK FOR `event_time` AS `event_time` - INTERVAL '5' SECOND,
    PRIMARY KEY (sessionId, childTripId) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.internal.trip_relation_rekeyed1',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    -- Security settings
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    -- Schema registry
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'key.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'key.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'value.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'value.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    -- Sink specific settings
    'sink.buffer-flush.max-rows' = '2000',
    'sink.buffer-flush.interval' = '1s',
    'sink.parallelism' = '1'
);
-- Insert data with new key
INSERT INTO trip_relation_rekeyed
SELECT whId,
    id,
    sessionId,
    xdock,
    parentTripId,
    childTripId,
    createdAt,
    `__op`,
    `__source_ts_ms`,
    `__source_snapshot`,
    `event_time`
FROM trip_relation_source
WHERE `event_time` > TIMESTAMP '1970-01-01 00:00:00';