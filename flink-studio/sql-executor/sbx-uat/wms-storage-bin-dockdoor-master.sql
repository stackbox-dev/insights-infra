SET 'pipeline.name' = 'WMS Storage Bin Dockdoor Master';
-- Create source tables (DDL for Kafka topics)
-- storage_bin source table
CREATE TABLE storage_bin (
    id STRING,
    whId BIGINT,
    code STRING,
    description STRING,
    binTypeId STRING,
    zoneId STRING,
    binHuId STRING,
    multiSku BOOLEAN,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    multiBatch BOOLEAN,
    pickingPosition INT,
    putawayPosition INT,
    status STRING,
    `rank` INT,
    aisle STRING,
    bay STRING,
    `level` STRING,
    `position` STRING,
    `depth` STRING,
    maxSkuCount INT,
    maxSkuBatchCount INT,
    attrs STRING,
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
    'topic' = 'sbx_uat.wms.public.storage_bin',
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
-- storage_bin_dockdoor source table
CREATE TABLE storage_bin_dockdoor (
    id STRING,
    whId BIGINT,
    binId STRING,
    dockdoorId STRING,
    active BOOLEAN,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    `usage` STRING,
    dockHandlingUnit STRING,
    multiTrip BOOLEAN,
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
    'topic' = 'sbx_uat.wms.public.storage_bin_dockdoor',
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
-- storage_dockdoor source table
CREATE TABLE storage_dockdoor (
    id STRING,
    whId BIGINT,
    code STRING,
    description STRING,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    maxQueue BIGINT,
    allowInbound BOOLEAN,
    allowOutbound BOOLEAN,
    allowReturns BOOLEAN,
    incompatibleVehicleTypes STRING,
    status STRING,
    incompatibleLoadTypes STRING,
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
    'topic' = 'sbx_uat.wms.public.storage_dockdoor',
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
-- storage_dockdoor_position source table
CREATE TABLE storage_dockdoor_position (
    id STRING,
    whId BIGINT,
    dockdoorId STRING,
    x DOUBLE,
    y DOUBLE,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    active BOOLEAN,
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
    'topic' = 'sbx_uat.wms.public.storage_dockdoor_position',
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

-- Create sink table: storage_bin_dockdoor_master
CREATE TABLE storage_bin_dockdoor_master (
    wh_id BIGINT,
    bin_id STRING,
    bin_code STRING,
    dockdoor_id STRING,
    dockdoor_code STRING,
    dockdoor_description STRING,
    `usage` STRING,
    active BOOLEAN,
    dock_handling_unit STRING,
    multi_trip BOOLEAN,
    max_queue BIGINT,
    allow_inbound BOOLEAN,
    allow_outbound BOOLEAN,
    allow_returns BOOLEAN,
    incompatible_vehicle_types STRING,
    incompatible_load_types STRING,
    dockdoor_x_coordinate DOUBLE,
    dockdoor_y_coordinate DOUBLE,
    dockdoor_position_active BOOLEAN,
    dockdoor_status STRING,
    -- Metadata
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    is_snapshot BOOLEAN,
    PRIMARY KEY (wh_id, bin_code, dockdoor_code) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.public.storage_bin_dockdoor_master',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'properties.transaction.id.prefix' = 'storage_bin_dockdoor_master_sink',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'key.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'key.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'value.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'value.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}'
);

-- Insert into storage_bin_dockdoor_master
INSERT INTO storage_bin_dockdoor_master
SELECT
    sb.whId AS wh_id,
    sb.id AS bin_id,
    sb.code AS bin_code,
    sd.id AS dockdoor_id,
    sd.code AS dockdoor_code,
    sd.description AS dockdoor_description,
    sbd.`usage`,
    sbd.active,
    sbd.dockHandlingUnit AS dock_handling_unit,
    sbd.multiTrip AS multi_trip,
    sd.maxQueue AS max_queue,
    sd.allowInbound AS allow_inbound,
    sd.allowOutbound AS allow_outbound,
    sd.allowReturns AS allow_returns,
    sd.incompatibleVehicleTypes AS incompatible_vehicle_types,
    sd.incompatibleLoadTypes AS incompatible_load_types,
    sdp.x AS dockdoor_x_coordinate,
    sdp.y AS dockdoor_y_coordinate,
    sdp.active AS dockdoor_position_active,
    sd.status AS dockdoor_status,
    -- Metadata
    GREATEST(
        COALESCE(sb.createdAt, TIMESTAMP '1970-01-01 00:00:00'),
        COALESCE(sbd.createdAt, TIMESTAMP '1970-01-01 00:00:00'),
        COALESCE(sd.createdAt, TIMESTAMP '1970-01-01 00:00:00')
    ) AS createdAt,
    GREATEST(
        COALESCE(sb.updatedAt, TIMESTAMP '1970-01-01 00:00:00'),
        COALESCE(sbd.updatedAt, TIMESTAMP '1970-01-01 00:00:00'),
        COALESCE(sd.updatedAt, TIMESTAMP '1970-01-01 00:00:00')
    ) AS updatedAt,
    COALESCE(sb.is_snapshot, FALSE) AND COALESCE(sbd.is_snapshot, FALSE) AND COALESCE(sd.is_snapshot, FALSE) AND COALESCE(sdp.is_snapshot, FALSE) AS is_snapshot
FROM storage_bin sb
    INNER JOIN storage_bin_dockdoor sbd ON sb.id = sbd.binId
    INNER JOIN storage_dockdoor sd ON sbd.dockdoorId = sd.id
    LEFT JOIN storage_dockdoor_position sdp ON sd.id = sdp.dockdoorId;