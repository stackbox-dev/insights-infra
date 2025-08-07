SET 'pipeline.name' = 'WMS Storage Area SLOC Mapping';
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
    `__source_snapshot` STRING,
    is_snapshot AS COALESCE(`__source_snapshot` IN (
        'true',
        'first',
        'first_in_data_collection',
        'last_in_data_collection',
        'last'
    ), FALSE),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.public.storage_area_sloc',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'properties.auto.offset.reset' = 'earliest',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'key.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'key.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
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
    is_snapshot BOOLEAN,
    PRIMARY KEY (wh_id, area_code, quality, sloc) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.public.storage_area_sloc_mapping',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'properties.transaction.id.prefix' = 'storage_area_sloc_mapping_sink',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'key.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'key.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
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
    sas.updatedAt,
    COALESCE(sas.is_snapshot, FALSE) AS is_snapshot
FROM storage_area_sloc sas;