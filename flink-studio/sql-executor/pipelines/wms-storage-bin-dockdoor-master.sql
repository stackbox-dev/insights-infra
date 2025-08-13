SET 'pipeline.name' = 'WMS Storage Bin Dockdoor Master';
SET 'table.exec.sink.not-null-enforcer' = 'drop';
SET 'parallelism.default' = '1';
SET 'table.optimizer.join-reorder-enabled' = 'true';
SET 'table.exec.resource.default-parallelism' = '1';
-- State TTL configuration to prevent unbounded state growth
-- State will be kept for 10 years after last access (master data)
SET 'table.exec.state.ttl' = '315360000000';
-- 10 years in milliseconds
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
-- Create source tables (DDL for Kafka topics)
-- storage_bin source table
CREATE TABLE storage_bin (
    id STRING NOT NULL,
    whId BIGINT NOT NULL,
    code STRING NOT NULL,
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
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = '${KAFKA_ENV}.wms.public.storage_bin',
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
-- storage_bin_dockdoor source table
CREATE TABLE storage_bin_dockdoor (
    id STRING NOT NULL,
    whId BIGINT NOT NULL,
    binId STRING NOT NULL,
    dockdoorId STRING NOT NULL,
    active BOOLEAN,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    `usage` STRING,
    dockHandlingUnit STRING,
    multiTrip BOOLEAN,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = '${KAFKA_ENV}.wms.public.storage_bin_dockdoor',
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
-- storage_dockdoor source table
CREATE TABLE storage_dockdoor (
    id STRING NOT NULL,
    whId BIGINT NOT NULL,
    code STRING NOT NULL,
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
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = '${KAFKA_ENV}.wms.public.storage_dockdoor',
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
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = '${KAFKA_ENV}.wms.public.storage_dockdoor_position',
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
    bin_created_at TIMESTAMP(3),
    bin_updated_at TIMESTAMP(3),
    dockdoor_created_at TIMESTAMP(3),
    dockdoor_updated_at TIMESTAMP(3),
    PRIMARY KEY (wh_id, bin_code, dockdoor_code) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = '${KAFKA_ENV}.wms.flink.storage_bin_dockdoor_master',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'sink.transactional-id-prefix' = 'storage_bin_dockdoor_master_sink',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
    'key.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'key.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
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
    sb.createdAt AS bin_created_at,
    sb.updatedAt AS bin_updated_at,
    sd.createdAt AS dockdoor_created_at,
    sd.updatedAt AS dockdoor_updated_at
FROM storage_bin sb
    INNER JOIN storage_bin_dockdoor sbd ON sb.id = sbd.binId
    INNER JOIN storage_dockdoor sd ON sbd.dockdoorId = sd.id
    LEFT JOIN storage_dockdoor_position sdp ON sd.id = sdp.dockdoorId;