SET 'pipeline.name' = 'WMS Storage Bin Split Tables';
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
    is_deleted BOOLEAN,
    `__snapshot` STRING,
    is_snapshot AS COALESCE(`__snapshot` IN (
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
-- storage_bin_fixed_mapping source table
CREATE TABLE storage_bin_fixed_mapping (
    id STRING,
    whId BIGINT,
    binId STRING,
    `value` STRING,
    active BOOLEAN,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    mode STRING,
    is_deleted BOOLEAN,
    `__snapshot` STRING,
    is_snapshot AS COALESCE(`__snapshot` IN (
        'true',
        'first',
        'first_in_data_collection',
        'last_in_data_collection',
        'last'
    ), FALSE),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.public.storage_bin_fixed_mapping',
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
-- storage_bin_type source table
CREATE TABLE storage_bin_type (
    id STRING,
    whId BIGINT,
    code STRING,
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
    is_deleted BOOLEAN,
    `__snapshot` STRING,
    is_snapshot AS COALESCE(`__snapshot` IN (
        'true',
        'first',
        'first_in_data_collection',
        'last_in_data_collection',
        'last'
    ), FALSE),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.public.storage_bin_type',
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
-- storage_zone source table
CREATE TABLE storage_zone (
    id STRING,
    whId BIGINT,
    code STRING,
    description STRING,
    face STRING,
    areaId STRING,
    active BOOLEAN,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    peripheral BOOLEAN,
    surveillanceConfig STRING,
    is_deleted BOOLEAN,
    `__snapshot` STRING,
    is_snapshot AS COALESCE(`__snapshot` IN (
        'true',
        'first',
        'first_in_data_collection',
        'last_in_data_collection',
        'last'
    ), FALSE),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.public.storage_zone',
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
-- storage_area source table
CREATE TABLE storage_area (
    id STRING,
    whId BIGINT,
    code STRING,
    description STRING,
    `type` STRING,
    active BOOLEAN,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    rollingDays INT,
    is_deleted BOOLEAN,
    `__snapshot` STRING,
    is_snapshot AS COALESCE(`__snapshot` IN (
        'true',
        'first',
        'first_in_data_collection',
        'last_in_data_collection',
        'last'
    ), FALSE),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.public.storage_area',
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
-- storage_position source table
CREATE TABLE storage_position (
    id STRING,
    whId BIGINT,
    storageId STRING,
    x1 DOUBLE,
    x2 DOUBLE,
    y1 DOUBLE,
    y2 DOUBLE,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    active BOOLEAN,
    is_deleted BOOLEAN,
    `__snapshot` STRING,
    is_snapshot AS COALESCE(`__snapshot` IN (
        'true',
        'first',
        'first_in_data_collection',
        'last_in_data_collection',
        'last'
    ), FALSE),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.public.storage_position',
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
    is_deleted BOOLEAN,
    `__snapshot` STRING,
    is_snapshot AS COALESCE(`__snapshot` IN (
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
    is_deleted BOOLEAN,
    `__snapshot` STRING,
    is_snapshot AS COALESCE(`__snapshot` IN (
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
    is_deleted BOOLEAN,
    `__snapshot` STRING,
    is_snapshot AS COALESCE(`__snapshot` IN (
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
    is_deleted BOOLEAN,
    `__snapshot` STRING,
    is_snapshot AS COALESCE(`__snapshot` IN (
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

-- Create sink table 1: storage_bins_master
CREATE TABLE storage_bins_master (
    wh_id BIGINT,
    bin_id STRING,
    bin_code STRING,
    bin_description STRING,
    bin_status STRING,
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
    bin_type_active BOOLEAN,
    -- Zone fields
    zone_id STRING,
    zone_code STRING,
    zone_description STRING,
    zone_face STRING,
    peripheral BOOLEAN,
    surveillance_config STRING,
    -- Area fields
    area_id STRING,
    area_code STRING,
    area_description STRING,
    area_type STRING,
    rolling_days INT,
    -- Position coordinates
    x1 DOUBLE,
    x2 DOUBLE,
    y1 DOUBLE,
    y2 DOUBLE,
    -- Mapping type
    bin_mapping STRING,
    -- Metadata
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    is_deleted BOOLEAN,
    is_snapshot BOOLEAN,
    PRIMARY KEY (wh_id, bin_code) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.internal.storage_bins_master',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'properties.transaction.id.prefix' = 'storage_bins_master_sink',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'key.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'key.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'value.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'value.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}'
);

-- Create sink table 2: storage_bin_dockdoors
CREATE TABLE storage_bin_dockdoors (
    wh_id BIGINT,
    bin_id STRING,
    bin_code STRING,
    dockdoor_id STRING,
    dockdoor_code STRING,
    dockdoor_description STRING,
    `usage` STRING,
    multi_trip BOOLEAN,
    max_queue BIGINT,
    allow_inbound BOOLEAN,
    allow_outbound BOOLEAN,
    allow_returns BOOLEAN,
    incompatible_vehicle_types STRING,
    incompatible_load_types STRING,
    dockdoor_x_coordinate DOUBLE,
    dockdoor_y_coordinate DOUBLE,
    dockdoor_status STRING,
    -- Metadata
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    is_deleted BOOLEAN,
    is_snapshot BOOLEAN,
    PRIMARY KEY (wh_id, bin_code, dockdoor_code) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.internal.storage_bin_dockdoors',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'properties.transaction.id.prefix' = 'storage_bin_dockdoors_sink',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'key.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'key.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'value.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'value.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}'
);

-- Create sink table 3: storage_area_sloc_mapping
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
    -- Metadata
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    is_deleted BOOLEAN,
    is_snapshot BOOLEAN,
    PRIMARY KEY (wh_id, area_code, quality, sloc) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.internal.storage_area_sloc_mapping',
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

-- Insert into storage_bins_master
INSERT INTO storage_bins_master
SELECT 
    sb.whId AS wh_id,
    sb.id AS bin_id,
    sb.code AS bin_code,
    sb.description AS bin_description,
    sb.status AS bin_status,
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
    sbt.active AS bin_type_active,
    -- Zone fields
    sz.id AS zone_id,
    sz.code AS zone_code,
    sz.description AS zone_description,
    sz.face AS zone_face,
    sz.peripheral,
    sz.surveillanceConfig AS surveillance_config,
    -- Area fields
    sa.id AS area_id,
    sa.code AS area_code,
    sa.description AS area_description,
    sa.`type` AS area_type,
    sa.rollingDays AS rolling_days,
    -- Position coordinates
    sp.x1,
    sp.x2,
    sp.y1,
    sp.y2,
    -- Mapping type
    CASE
        WHEN sbfm.active = true THEN 'FIXED'
        ELSE 'DYNAMIC'
    END AS bin_mapping,
    -- Metadata
    sb.createdAt,
    sb.updatedAt,
    sb.is_deleted,
    sb.is_snapshot
FROM storage_bin AS sb
    LEFT JOIN storage_bin_fixed_mapping sbfm ON sb.id = sbfm.binId AND sbfm.active = true
    LEFT JOIN storage_bin_type sbt ON sb.binTypeId = sbt.id
    LEFT JOIN storage_zone sz ON sb.zoneId = sz.id
    LEFT JOIN storage_area sa ON sz.areaId = sa.id
    LEFT JOIN storage_position sp ON sp.storageId = sb.id;

-- Insert into storage_bin_dockdoors
INSERT INTO storage_bin_dockdoors
SELECT
    sb.whId AS wh_id,
    sb.id AS bin_id,
    sb.code AS bin_code,
    sd.id AS dockdoor_id,
    sd.code AS dockdoor_code,
    sd.description AS dockdoor_description,
    sbd.`usage`,
    sbd.multiTrip AS multi_trip,
    sd.maxQueue AS max_queue,
    sd.allowInbound AS allow_inbound,
    sd.allowOutbound AS allow_outbound,
    sd.allowReturns AS allow_returns,
    sd.incompatibleVehicleTypes AS incompatible_vehicle_types,
    sd.incompatibleLoadTypes AS incompatible_load_types,
    sdp.x AS dockdoor_x_coordinate,
    sdp.y AS dockdoor_y_coordinate,
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
    CASE 
        WHEN sb.is_deleted = true OR sbd.is_deleted = true OR sd.is_deleted = true 
        THEN true 
        ELSE false 
    END AS is_deleted,
    COALESCE(sb.is_snapshot, sbd.is_snapshot, sd.is_snapshot, false) AS is_snapshot
FROM storage_bin sb
    INNER JOIN storage_bin_dockdoor sbd ON sb.id = sbd.binId
    INNER JOIN storage_dockdoor sd ON sbd.dockdoorId = sd.id
    LEFT JOIN storage_dockdoor_position sdp ON sd.id = sdp.dockdoorId;

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
    -- Metadata
    sas.createdAt,
    sas.updatedAt,
    CASE 
        WHEN sas.is_deleted = true OR sas.deactivatedAt IS NOT NULL 
        THEN true 
        ELSE false 
    END AS is_deleted,
    sas.is_snapshot
FROM storage_area_sloc sas;