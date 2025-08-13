SET 'pipeline.name' = 'WMS Storage Bin Master';
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
    binTypeId STRING NOT NULL,
    zoneId STRING NOT NULL,
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
-- storage_bin_fixed_mapping source table
CREATE TABLE storage_bin_fixed_mapping (
    id STRING NOT NULL,
    whId BIGINT NOT NULL,
    binId STRING NOT NULL,
    `value` STRING,
    active BOOLEAN,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    mode STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = '${KAFKA_ENV}.wms.public.storage_bin_fixed_mapping',
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
-- storage_bin_type source table
CREATE TABLE storage_bin_type (
    id STRING NOT NULL,
    whId BIGINT NOT NULL,
    code STRING NOT NULL,
    description STRING,
    maxVolumeInCC DOUBLE,
    maxWeightInKG DOUBLE,
    active BOOLEAN,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    palletCapacity INT,
    storageHUType STRING,
    auxiliaryBin BOOLEAN,
    huMultiSku BOOLEAN,
    huMultiBatch BOOLEAN,
    useDerivedPalletBestFit BOOLEAN,
    onlyFullPallet BOOLEAN,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = '${KAFKA_ENV}.wms.public.storage_bin_type',
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
-- storage_zone source table
CREATE TABLE storage_zone (
    id STRING NOT NULL,
    whId BIGINT NOT NULL,
    code STRING NOT NULL,
    description STRING,
    face STRING,
    areaId STRING NOT NULL,
    active BOOLEAN,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    peripheral BOOLEAN,
    surveillanceConfig STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = '${KAFKA_ENV}.wms.public.storage_zone',
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
-- storage_area source table
CREATE TABLE storage_area (
    id STRING NOT NULL,
    whId BIGINT NOT NULL,
    code STRING NOT NULL,
    description STRING,
    `type` STRING,
    active BOOLEAN,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    rollingDays INT,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = '${KAFKA_ENV}.wms.public.storage_area',
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
-- storage_position source table
CREATE TABLE storage_position (
    id STRING NOT NULL,
    whId BIGINT NOT NULL,
    storageId STRING NOT NULL,
    x1 DOUBLE,
    x2 DOUBLE,
    y1 DOUBLE,
    y2 DOUBLE,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    active BOOLEAN,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = '${KAFKA_ENV}.wms.public.storage_position',
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

-- Create sink table: storage_bin_master
CREATE TABLE storage_bin_master (
    wh_id BIGINT NOT NULL,
    bin_id STRING NOT NULL,
    bin_code STRING NOT NULL,
    bin_description STRING,
    bin_status STRING,
    bin_hu_id STRING,
    multi_sku BOOLEAN,
    multi_batch BOOLEAN,
    picking_position INT,
    putaway_position INT,
    `rank` INT,
    aisle STRING,
    bay STRING,
    `level` STRING,
    `position` STRING,
    `depth` STRING,
    max_sku_count INT,
    max_sku_batch_count INT,
    -- Bin type fields
    bin_type_id STRING,
    bin_type_code STRING,
    bin_type_description STRING,
    max_volume_in_cc DOUBLE,
    max_weight_in_kg DOUBLE,
    pallet_capacity INT,
    storage_hu_type STRING,
    auxiliary_bin BOOLEAN,
    hu_multi_sku BOOLEAN,
    hu_multi_batch BOOLEAN,
    use_derived_pallet_best_fit BOOLEAN,
    only_full_pallet BOOLEAN,
    bin_type_active BOOLEAN,
    -- Zone fields
    zone_id STRING,
    zone_code STRING,
    zone_description STRING,
    zone_face STRING,
    peripheral BOOLEAN,
    surveillance_config STRING,
    zone_active BOOLEAN,
    -- Area fields
    area_id STRING,
    area_code STRING,
    area_description STRING,
    area_type STRING,
    rolling_days INT,
    area_active BOOLEAN,
    -- Position coordinates
    x1 DOUBLE,
    x2 DOUBLE,
    y1 DOUBLE,
    y2 DOUBLE,
    position_active BOOLEAN,
    -- Bin attrs and mapping type
    attrs STRING,
    bin_mapping STRING,
    -- Individual table timestamps
    bin_created_at TIMESTAMP(3),
    bin_updated_at TIMESTAMP(3),
    bin_type_created_at TIMESTAMP(3),
    bin_type_updated_at TIMESTAMP(3),
    zone_created_at TIMESTAMP(3),
    zone_updated_at TIMESTAMP(3),
    area_created_at TIMESTAMP(3),
    area_updated_at TIMESTAMP(3),
    position_created_at TIMESTAMP(3),
    position_updated_at TIMESTAMP(3),
    mapping_created_at TIMESTAMP(3),
    mapping_updated_at TIMESTAMP(3),
    -- Aggregated metadata
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    PRIMARY KEY (wh_id, bin_code) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = '${KAFKA_ENV}.wms.flink.storage_bin_master',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'sink.transactional-id-prefix' = 'storage_bin_master_sink',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
    'key.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'key.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
    'value.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'value.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}'
);

-- Insert into storage_bin_master
INSERT INTO storage_bin_master
SELECT 
    sb.whId AS wh_id,
    sb.id AS bin_id,
    sb.code AS bin_code,
    sb.description AS bin_description,
    sb.status AS bin_status,
    sb.binHuId AS bin_hu_id,
    sb.multiSku AS multi_sku,
    sb.multiBatch AS multi_batch,
    sb.pickingPosition AS picking_position,
    sb.putawayPosition AS putaway_position,
    sb.`rank`,
    sb.aisle,
    sb.bay,
    sb.`level`,
    sb.`position`,
    sb.`depth`,
    sb.maxSkuCount AS max_sku_count,
    sb.maxSkuBatchCount AS max_sku_batch_count,
    -- Bin type fields
    sbt.id AS bin_type_id,
    sbt.code AS bin_type_code,
    sbt.description AS bin_type_description,
    sbt.maxVolumeInCC AS max_volume_in_cc,
    sbt.maxWeightInKG AS max_weight_in_kg,
    sbt.palletCapacity AS pallet_capacity,
    sbt.storageHUType AS storage_hu_type,
    sbt.auxiliaryBin AS auxiliary_bin,
    sbt.huMultiSku AS hu_multi_sku,
    sbt.huMultiBatch AS hu_multi_batch,
    sbt.useDerivedPalletBestFit AS use_derived_pallet_best_fit,
    sbt.onlyFullPallet AS only_full_pallet,
    sbt.active AS bin_type_active,
    -- Zone fields
    sz.id AS zone_id,
    sz.code AS zone_code,
    sz.description AS zone_description,
    sz.face AS zone_face,
    sz.peripheral,
    sz.surveillanceConfig AS surveillance_config,
    sz.active AS zone_active,
    -- Area fields
    sa.id AS area_id,
    sa.code AS area_code,
    sa.description AS area_description,
    sa.`type` AS area_type,
    sa.rollingDays AS rolling_days,
    sa.active AS area_active,
    -- Position coordinates
    sp.x1,
    sp.x2,
    sp.y1,
    sp.y2,
    sp.active AS position_active,
    -- Bin attrs and mapping type
    sb.attrs,
    CASE
        WHEN sbfm.active = true THEN 'FIXED'
        ELSE 'DYNAMIC'
    END AS bin_mapping,
    -- Individual table timestamps
    sb.createdAt AS bin_created_at,
    sb.updatedAt AS bin_updated_at,
    sbt.createdAt AS bin_type_created_at,
    sbt.updatedAt AS bin_type_updated_at,
    sz.createdAt AS zone_created_at,
    sz.updatedAt AS zone_updated_at,
    sa.createdAt AS area_created_at,
    sa.updatedAt AS area_updated_at,
    sp.createdAt AS position_created_at,
    sp.updatedAt AS position_updated_at,
    sbfm.createdAt AS mapping_created_at,
    sbfm.updatedAt AS mapping_updated_at,
    -- Aggregated metadata (MIN for created, MAX for updated)
    LEAST(
        COALESCE(sb.createdAt, TIMESTAMP '2099-12-31 23:59:59'),
        COALESCE(sbt.createdAt, TIMESTAMP '2099-12-31 23:59:59'),
        COALESCE(sz.createdAt, TIMESTAMP '2099-12-31 23:59:59'),
        COALESCE(sa.createdAt, TIMESTAMP '2099-12-31 23:59:59'),
        COALESCE(sp.createdAt, TIMESTAMP '2099-12-31 23:59:59'),
        COALESCE(sbfm.createdAt, TIMESTAMP '2099-12-31 23:59:59')
    ) AS created_at,
    GREATEST(
        COALESCE(sb.updatedAt, TIMESTAMP '1970-01-01 00:00:00'),
        COALESCE(sbt.updatedAt, TIMESTAMP '1970-01-01 00:00:00'),
        COALESCE(sz.updatedAt, TIMESTAMP '1970-01-01 00:00:00'),
        COALESCE(sa.updatedAt, TIMESTAMP '1970-01-01 00:00:00'),
        COALESCE(sp.updatedAt, TIMESTAMP '1970-01-01 00:00:00'),
        COALESCE(sbfm.updatedAt, TIMESTAMP '1970-01-01 00:00:00')
    ) AS updated_at
FROM storage_bin AS sb
    INNER JOIN storage_bin_type sbt ON sb.binTypeId = sbt.id
    INNER JOIN storage_zone sz ON sb.zoneId = sz.id
    INNER JOIN storage_area sa ON sz.areaId = sa.id
    LEFT JOIN storage_position sp ON sp.storageId = sb.id
    LEFT JOIN storage_bin_fixed_mapping sbfm ON sb.id = sbfm.binId AND sbfm.active = true;