SET 'pipeline.name' = 'WMS Storage Area SLOC Mapping';
SET 'table.exec.sink.not-null-enforcer' = 'drop';
SET 'parallelism.default' = '1';
SET 'table.optimizer.join-reorder-enabled' = 'true';
SET 'table.exec.resource.default-parallelism' = '1';
-- State TTL configuration to prevent unbounded state growth
-- State will be kept for 12 hours after last access
SET 'table.exec.state.ttl' = '43200000';
-- 12 hours in milliseconds
-- Performance optimizations
SET 'taskmanager.memory.managed.fraction' = '0.8';
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '1s';
SET 'table.exec.mini-batch.size' = '5000';
SET 'execution.checkpointing.interval' = '600000';
SET 'execution.checkpointing.timeout' = '1800000';
SET 'state.backend.incremental' = 'true';
SET 'state.backend.rocksdb.compression.type' = 'LZ4';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.optimizer.multiple-input-enabled' = 'true';
-- Create source table (DDL for Kafka topic)
-- storage_area_sloc source table
CREATE TABLE storage_area_sloc (
    whId BIGINT,
    id STRING,
    areaCode STRING,
    quality STRING,
    sloc STRING,
    slocDescription STRING,
    clientQuality STRING,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    deactivatedAt TIMESTAMP(3),
    inventoryVisible BOOLEAN,
    erpToWMS BOOLEAN,
    iloc STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = '${KAFKA_ENV}.wms.public.storage_area_sloc',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'properties.auto.offset.reset' = 'earliest',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
    'key.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'key.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
    'value.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'value.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}'
);

-- Create sink table: storage_area_sloc_mapping
CREATE TABLE storage_area_sloc_mapping (
    wh_id BIGINT,
    area_code STRING,
    quality STRING,
    sloc STRING,
    sloc_description STRING,
    client_quality STRING,
    inventory_visible BOOLEAN,
    erp_to_wms BOOLEAN,
    iloc STRING,
    deactivatedAt TIMESTAMP(3),
    -- Metadata
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    PRIMARY KEY (wh_id, area_code, quality, sloc) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = '${KAFKA_ENV}.wms.public.storage_area_sloc_mapping',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'sink.transactional-id-prefix' = 'storage_area_sloc_mapping_sink',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
    'key.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'key.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
    'value.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'value.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}'
);

-- Insert into storage_area_sloc_mapping
INSERT INTO storage_area_sloc_mapping
SELECT DISTINCT
    sas.whId AS wh_id,
    sas.areaCode AS area_code,
    sas.quality,
    sas.sloc,
    sas.slocDescription AS sloc_description,
    sas.clientQuality AS client_quality,
    sas.inventoryVisible AS inventory_visible,
    sas.erpToWMS AS erp_to_wms,
    sas.iloc,
    sas.deactivatedAt,
    -- Metadata
    sas.createdAt,
    sas.updatedAt
FROM storage_area_sloc sas;