-- Create source tables (DDL for Kafka topics)
-- storage_bin source table
CREATE TABLE `sbx-uat.wms.public.storage_bin` (
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
    proc_time AS PROCTIME(),
    event_time AS CASE
        WHEN updatedAt > createdAt THEN updatedAt
        ELSE createdAt
    END,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx-uat.wms.public.storage_bin',
    'properties.bootstrap.servers' = 'bootstrap.sbx-kafka-cluster.asia-south1.managedkafka.sbx-stag.cloud.goog:9092',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'OAUTHBEARER',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;',
    'properties.sasl.login.callback.handler.class' = 'com.google.cloud.hosted.kafka.auth.GcpLoginCallbackHandler',
    'properties.auto.offset.reset' = 'earliest',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'http://cp-schema-registry.kafka',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'http://cp-schema-registry.kafka'
);
-- storage_bin_fixed_mapping source table
CREATE TABLE `sbx-uat.wms.public.storage_bin_fixed_mapping` (
    id STRING,
    whId BIGINT,
    binId STRING,
    `value` STRING,
    active BOOLEAN,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    mode STRING,
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
    'topic' = 'sbx-uat.wms.public.storage_bin_fixed_mapping',
    'properties.bootstrap.servers' = 'bootstrap.sbx-kafka-cluster.asia-south1.managedkafka.sbx-stag.cloud.goog:9092',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'OAUTHBEARER',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;',
    'properties.sasl.login.callback.handler.class' = 'com.google.cloud.hosted.kafka.auth.GcpLoginCallbackHandler',
    'properties.auto.offset.reset' = 'earliest',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'http://cp-schema-registry.kafka',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'http://cp-schema-registry.kafka'
);
-- storage_bin_type source table
CREATE TABLE `sbx-uat.wms.public.storage_bin_type` (
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
    proc_time AS PROCTIME(),
    event_time AS CASE
        WHEN updatedAt > createdAt THEN updatedAt
        ELSE createdAt
    END,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx-uat.wms.public.storage_bin_type',
    'properties.bootstrap.servers' = 'bootstrap.sbx-kafka-cluster.asia-south1.managedkafka.sbx-stag.cloud.goog:9092',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'OAUTHBEARER',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;',
    'properties.sasl.login.callback.handler.class' = 'com.google.cloud.hosted.kafka.auth.GcpLoginCallbackHandler',
    'properties.auto.offset.reset' = 'earliest',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'http://cp-schema-registry.kafka',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'http://cp-schema-registry.kafka'
);
-- storage_zone source table
CREATE TABLE `sbx-uat.wms.public.storage_zone` (
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
    proc_time AS PROCTIME(),
    event_time AS CASE
        WHEN updatedAt > createdAt THEN updatedAt
        ELSE createdAt
    END,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx-uat.wms.public.storage_zone',
    'properties.bootstrap.servers' = 'bootstrap.sbx-kafka-cluster.asia-south1.managedkafka.sbx-stag.cloud.goog:9092',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'OAUTHBEARER',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;',
    'properties.sasl.login.callback.handler.class' = 'com.google.cloud.hosted.kafka.auth.GcpLoginCallbackHandler',
    'properties.auto.offset.reset' = 'earliest',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'http://cp-schema-registry.kafka',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'http://cp-schema-registry.kafka'
);
-- storage_area source table
CREATE TABLE `sbx-uat.wms.public.storage_area` (
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
    proc_time AS PROCTIME(),
    event_time AS CASE
        WHEN updatedAt > createdAt THEN updatedAt
        ELSE createdAt
    END,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx-uat.wms.public.storage_area',
    'properties.bootstrap.servers' = 'bootstrap.sbx-kafka-cluster.asia-south1.managedkafka.sbx-stag.cloud.goog:9092',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'OAUTHBEARER',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;',
    'properties.sasl.login.callback.handler.class' = 'com.google.cloud.hosted.kafka.auth.GcpLoginCallbackHandler',
    'properties.auto.offset.reset' = 'earliest',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'http://cp-schema-registry.kafka',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'http://cp-schema-registry.kafka'
);
-- storage_position source table
CREATE TABLE `sbx-uat.wms.public.storage_position` (
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
    proc_time AS PROCTIME(),
    event_time AS CASE
        WHEN updatedAt > createdAt THEN updatedAt
        ELSE createdAt
    END,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx-uat.wms.public.storage_position',
    'properties.bootstrap.servers' = 'bootstrap.sbx-kafka-cluster.asia-south1.managedkafka.sbx-stag.cloud.goog:9092',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'OAUTHBEARER',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;',
    'properties.sasl.login.callback.handler.class' = 'com.google.cloud.hosted.kafka.auth.GcpLoginCallbackHandler',
    'properties.auto.offset.reset' = 'earliest',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'http://cp-schema-registry.kafka',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'http://cp-schema-registry.kafka'
);
-- storage_area_sloc source table
CREATE TABLE `sbx-uat.wms.public.storage_area_sloc` (
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
    proc_time AS PROCTIME(),
    event_time AS CASE
        WHEN updatedAt > createdAt THEN updatedAt
        ELSE createdAt
    END,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx-uat.wms.public.storage_area_sloc',
    'properties.bootstrap.servers' = 'bootstrap.sbx-kafka-cluster.asia-south1.managedkafka.sbx-stag.cloud.goog:9092',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'OAUTHBEARER',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;',
    'properties.sasl.login.callback.handler.class' = 'com.google.cloud.hosted.kafka.auth.GcpLoginCallbackHandler',
    'properties.auto.offset.reset' = 'earliest',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'http://cp-schema-registry.kafka',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'http://cp-schema-registry.kafka'
);
-- storage_bin_dockdoor source table
CREATE TABLE `sbx-uat.wms.public.storage_bin_dockdoor` (
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
    proc_time AS PROCTIME(),
    event_time AS CASE
        WHEN updatedAt > createdAt THEN updatedAt
        ELSE createdAt
    END,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx-uat.wms.public.storage_bin_dockdoor',
    'properties.bootstrap.servers' = 'bootstrap.sbx-kafka-cluster.asia-south1.managedkafka.sbx-stag.cloud.goog:9092',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'OAUTHBEARER',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;',
    'properties.sasl.login.callback.handler.class' = 'com.google.cloud.hosted.kafka.auth.GcpLoginCallbackHandler',
    'properties.auto.offset.reset' = 'earliest',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'http://cp-schema-registry.kafka',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'http://cp-schema-registry.kafka'
);
-- storage_dockdoor source table
CREATE TABLE `sbx-uat.wms.public.storage_dockdoor` (
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
    proc_time AS PROCTIME(),
    event_time AS CASE
        WHEN updatedAt > createdAt THEN updatedAt
        ELSE createdAt
    END,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx-uat.wms.public.storage_dockdoor',
    'properties.bootstrap.servers' = 'bootstrap.sbx-kafka-cluster.asia-south1.managedkafka.sbx-stag.cloud.goog:9092',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'OAUTHBEARER',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;',
    'properties.sasl.login.callback.handler.class' = 'com.google.cloud.hosted.kafka.auth.GcpLoginCallbackHandler',
    'properties.auto.offset.reset' = 'earliest',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'http://cp-schema-registry.kafka',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'http://cp-schema-registry.kafka'
);
-- storage_dockdoor_position source table
CREATE TABLE `sbx-uat.wms.public.storage_dockdoor_position` (
    id STRING,
    whId BIGINT,
    dockdoorId STRING,
    x DOUBLE,
    y DOUBLE,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    active BOOLEAN,
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
    'topic' = 'sbx-uat.wms.public.storage_dockdoor_position',
    'properties.bootstrap.servers' = 'bootstrap.sbx-kafka-cluster.asia-south1.managedkafka.sbx-stag.cloud.goog:9092',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'OAUTHBEARER',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;',
    'properties.sasl.login.callback.handler.class' = 'com.google.cloud.hosted.kafka.auth.GcpLoginCallbackHandler',
    'properties.auto.offset.reset' = 'earliest',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'http://cp-schema-registry.kafka',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'http://cp-schema-registry.kafka'
);
-- Create final summary table structure (destination table)
CREATE TABLE `sbx-uat.wms.public.storage_bin_summary` (
    wh_id BIGINT,
    bin_code STRING,
    quality STRING,
    sd_code STRING,
    bin_description STRING,
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
    zone_code STRING,
    zone_description STRING,
    zone_face STRING,
    peripheral BOOLEAN,
    surveillance_config STRING,
    area_code STRING,
    sa_description STRING,
    area_type STRING,
    rolling_days INT,
    x1 DOUBLE,
    x2 DOUBLE,
    y1 DOUBLE,
    y2 DOUBLE,
    sloc STRING,
    sloc_description STRING,
    client_quality STRING,
    inventory_visible BOOLEAN,
    erp_to_wms BOOLEAN,
    `usage` STRING,
    multi_trip BOOLEAN,
    sd_description STRING,
    max_queue BIGINT,
    allow_inbound BOOLEAN,
    allow_outbound BOOLEAN,
    allow_returns BOOLEAN,
    incompatible_vehicle_types STRING,
    incompatible_load_types STRING,
    dockdoor_x_coordinate DOUBLE,
    dockdoor_y_coordinate DOUBLE,
    sb_status STRING,
    sbt_active BOOLEAN,
    bin_mapping STRING,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    is_deleted BOOLEAN,
    proc_time AS PROCTIME(),
    event_time AS CASE
        WHEN updatedAt > createdAt THEN updatedAt
        ELSE createdAt
    END,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (wh_id, bin_code, quality, sd_code) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx-uat.wms.public.storage_bin_summary',
    'properties.bootstrap.servers' = 'bootstrap.sbx-kafka-cluster.asia-south1.managedkafka.sbx-stag.cloud.goog:9092',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'OAUTHBEARER',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;',
    'properties.sasl.login.callback.handler.class' = 'com.google.cloud.hosted.kafka.auth.GcpLoginCallbackHandler',
    'properties.transaction.id.prefix' = 'storage_bin_summary_sink',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'http://cp-schema-registry.kafka',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'http://cp-schema-registry.kafka'
);
-- Continuously populate the summary table from source tables
INSERT INTO `sbx-uat.wms.public.storage_bin_summary`
SELECT sb.`whId` AS wh_id,
    sb.code AS bin_code,
    case
        when sac.quality is null then '-'
        else sac.quality
    end as quality,
    case
        when sd.code is null then '-'
        else sd.code
    end AS sd_code,
    sb.description AS bin_description,
    sb.`multiSku` AS multi_sku,
    sb.`multiBatch` AS multi_batch,
    sb.`pickingPosition` AS picking_position,
    sb.`putawayPosition` AS putaway_position,
    sb.`rank`,
    sb.aisle,
    sb.bay,
    sb.`level`,
    sb.`position`,
    sb.`depth`,
    sb.`maxSkuCount` AS max_sku_count,
    sb.`maxSkuBatchCount` AS max_sku_batch_count,
    sbt.code AS bin_type_code,
    sbt.description AS bin_type_description,
    sbt.`maxVolumeInCC` AS max_volume_in_cc,
    sbt.`maxWeightInKG` AS max_weight_in_kg,
    sbt.`palletCapacity` AS pallet_capacity,
    sbt.`storageHUType` AS storage_hu_type,
    sbt.`auxiliaryBin` AS auxiliary_bin,
    sbt.`huMultiSku` AS hu_multi_sku,
    sbt.`huMultiBatch` AS hu_multi_batch,
    sbt.`useDerivedPalletBestFit` AS use_derived_pallet_best_fit,
    sz.code AS zone_code,
    sz.description AS zone_description,
    sz.face AS zone_face,
    sz.peripheral,
    sz.`surveillanceConfig` AS surveillance_config,
    sa.code AS area_code,
    sa.description AS sa_description,
    sa.`type` AS area_type,
    sa.`rollingDays` AS rolling_days,
    ss.x1,
    ss.x2,
    ss.y1,
    ss.y2,
    sac.sloc,
    sac.`slocDescription` AS sloc_description,
    sac.`clientQuality` AS client_quality,
    sac.`inventoryVisible` AS inventory_visible,
    sac.`erpToWMS` AS erp_to_wms,
    sbd.`usage`,
    sbd.`multiTrip` AS multi_trip,
    sd.description AS sd_description,
    sd.`maxQueue` AS max_queue,
    sd.`allowInbound` AS allow_inbound,
    sd.`allowOutbound` AS allow_outbound,
    sd.`allowReturns` AS allow_returns,
    sd.`incompatibleVehicleTypes` AS incompatible_vehicle_types,
    sd.`incompatibleLoadTypes` AS incompatible_load_types,
    sdp.x AS dockdoor_x_coordinate,
    sdp.y AS dockdoor_y_coordinate,
    sb.status AS sb_status,
    sbt.active AS sbt_active,
    CASE
        WHEN sbfm.active = true THEN 'FIXED'
        ELSE 'DYNAMIC'
    END AS bin_mapping,
    sb.createdAt,
    sb.updatedAt,
    sb.is_deleted
FROM `sbx-uat.wms.public.storage_bin` AS sb
    LEFT JOIN `sbx-uat.wms.public.storage_bin_fixed_mapping` sbfm ON sb.id = sbfm.`binId`
    LEFT JOIN `sbx-uat.wms.public.storage_bin_type` sbt ON sb.`binTypeId` = sbt.id
    LEFT JOIN `sbx-uat.wms.public.storage_zone` sz ON sb.`zoneId` = sz.id
    LEFT JOIN `sbx-uat.wms.public.storage_area` sa ON sz.`areaId` = sa.id
    LEFT JOIN `sbx-uat.wms.public.storage_position` ss ON ss.`storageId` = sb.id
    LEFT JOIN `sbx-uat.wms.public.storage_area_sloc` sac ON sa.`whId` = sac.`whId`
    AND sa.`code` = sac.`areaCode`
    LEFT JOIN `sbx-uat.wms.public.storage_bin_dockdoor` sbd ON sb.id = sbd.`binId`
    LEFT JOIN `sbx-uat.wms.public.storage_dockdoor` sd ON sbd.`dockdoorId` = sd.id
    LEFT JOIN `sbx-uat.wms.public.storage_dockdoor_position` sdp ON sd.`id` = sdp.`dockdoorId`;