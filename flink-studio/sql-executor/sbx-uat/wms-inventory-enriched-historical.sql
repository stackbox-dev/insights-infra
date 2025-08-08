-- Historical WMS Inventory Events Enrichment Pipeline
-- 
-- Purpose: Enriches inventory events with handling unit, handling unit kind, and storage bin master data
-- Uses BATCH mode for processing all historical data
--
-- Key Configuration:
-- 1. BATCH execution mode for processing complete historical dataset
-- 2. Starts from earliest offset to process all available data
-- 3. Uses kafka connector with scan.bounded.mode for bounded processing
-- 4. Creates views to get latest dimension data for joins
--
-- Usage: Run this first to process all historical data before starting real-time pipeline

SET 'pipeline.name' = 'WMS Inventory Events Historical Enrichment';
SET 'execution.runtime-mode' = 'BATCH';
SET 'table.exec.sink.not-null-enforcer' = 'drop';
SET 'parallelism.default' = '4';
SET 'table.optimizer.join-reorder-enabled' = 'false';
SET 'table.exec.legacy-cast-behaviour' = 'enabled';
SET 'table.exec.resource.default-parallelism' = '4';

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

-- Source idle timeout to handle temporarily inactive sources
SET 'table.exec.source.idle-timeout' = '30s';

-- Source: Inventory events basic data (bounded stream with processing time)
CREATE TABLE inventory_events_basic (
    -- Handling unit event fields
    hu_event_id STRING NOT NULL,
    wh_id BIGINT,
    hu_event_seq BIGINT,
    hu_id STRING,
    hu_event_type STRING,
    hu_event_timestamp TIMESTAMP(3),
    hu_event_payload STRING,
    hu_event_attrs STRING,
    session_id STRING,
    task_id STRING,
    correlation_id STRING,
    storage_id STRING,
    outer_hu_id STRING,
    effective_storage_id STRING,
    -- Handling unit quant event fields
    quant_event_id STRING NOT NULL,
    sku_id STRING,
    uom STRING,
    bucket STRING,
    batch STRING,
    price STRING,
    inclusion_status STRING,
    locked_by_task_id STRING,
    lock_mode STRING,
    qty_added INT,
    -- Processing time for historical data
    proc_time AS PROCTIME()
) WITH (
    'connector' = 'kafka',
    'topic' = 'sbx_uat.wms.internal.inventory_events_basic',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.group.id' = 'sbx-uat-wms-inventory-enriched',
    'properties.enable.auto.commit' = 'true',
    'properties.auto.commit.interval.ms' = '5000',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'scan.startup.mode' = 'earliest-offset',
    'scan.bounded.mode' = 'latest-offset',
    'format' = 'avro-confluent',
    'avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}'
);

-- Dimension: Handling Units
CREATE TABLE handling_units (
    `whId` BIGINT NOT NULL,
    id STRING NOT NULL,
    code STRING,
    `kindId` STRING,
    `sessionId` STRING,
    `taskId` STRING,
    `storageId` STRING,
    `outerHuId` STRING,
    state STRING,
    attrs STRING,
    `createdAt` TIMESTAMP(3),
    `updatedAt` TIMESTAMP(3),
    `lockTaskId` STRING,
    `effectiveStorageId` STRING,
    -- Event time for versioning
    event_time AS COALESCE(`updatedAt`, `createdAt`, TIMESTAMP '1970-01-01 00:00:00'),
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    proc_time AS PROCTIME()
) WITH (
    'connector' = 'kafka',
    'topic' = 'sbx_uat.wms.public.handling_unit',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'scan.bounded.mode' = 'latest-offset',
    'scan.startup.mode' = 'earliest-offset',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'format' = 'avro-confluent',
    'avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}'
);

-- Dimension: Handling Unit Kinds
CREATE TABLE handling_unit_kinds (
    `whId` BIGINT NOT NULL,
    id STRING NOT NULL,
    code STRING,
    name STRING,
    attrs STRING,
    active BOOLEAN,
    `createdAt` TIMESTAMP(3),
    `updatedAt` TIMESTAMP(3),
    `maxVolume` DOUBLE,
    `maxWeight` DOUBLE,
    `usageType` STRING,
    abbr STRING,
    length DOUBLE,
    breadth DOUBLE,
    height DOUBLE,
    weight DOUBLE,
    -- Event time for versioning
    event_time AS COALESCE(`updatedAt`, `createdAt`, TIMESTAMP '1970-01-01 00:00:00'),
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    proc_time AS PROCTIME()
) WITH (
    'connector' = 'kafka',
    'topic' = 'sbx_uat.wms.public.handling_unit_kind',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'scan.bounded.mode' = 'latest-offset',
    'scan.startup.mode' = 'earliest-offset',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'format' = 'avro-confluent',
    'avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}'
);

-- Dimension: Storage Bin (for getting bin_code from bin_id)
CREATE TABLE storage_bin (
    `whId` BIGINT NOT NULL,
    id STRING NOT NULL,
    code STRING,
    `createdAt` TIMESTAMP(3),
    `updatedAt` TIMESTAMP(3),
    -- Event time for versioning
    event_time AS COALESCE(`updatedAt`, `createdAt`, TIMESTAMP '1970-01-01 00:00:00'),
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    proc_time AS PROCTIME()
) WITH (
    'connector' = 'kafka',
    'topic' = 'sbx_uat.wms.public.storage_bin',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'scan.bounded.mode' = 'latest-offset',
    'scan.startup.mode' = 'earliest-offset',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'format' = 'avro-confluent',
    'avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}'
);

-- Dimension: Storage Bin Master (uses bin_code as part of primary key)
CREATE TABLE storage_bin_master (
    wh_id BIGINT NOT NULL,
    bin_id STRING,
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
    level STRING,
    `position` STRING,
    depth STRING,
    max_sku_count INT,
    max_sku_batch_count INT,
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
    zone_id STRING,
    zone_code STRING,
    zone_description STRING,
    zone_face STRING,
    peripheral BOOLEAN,
    surveillance_config STRING,
    zone_active BOOLEAN,
    area_id STRING,
    area_code STRING,
    area_description STRING,
    area_type STRING,
    rolling_days INT,
    area_active BOOLEAN,
    x1 DOUBLE,
    x2 DOUBLE,
    y1 DOUBLE,
    y2 DOUBLE,
    position_active BOOLEAN,
    attrs STRING,
    bin_mapping STRING,
    `createdAt` TIMESTAMP(3),
    `updatedAt` TIMESTAMP(3),
    -- Event time for versioning
    event_time AS COALESCE(`updatedAt`, `createdAt`, TIMESTAMP '1970-01-01 00:00:00'),
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    proc_time AS PROCTIME()
) WITH (
    'connector' = 'kafka',
    'topic' = 'sbx_uat.wms.public.storage_bin_master',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'scan.bounded.mode' = 'latest-offset',
    'scan.startup.mode' = 'earliest-offset',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'format' = 'avro-confluent',
    'avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}'
);

-- Dimension: SKUs Master (from Encarta)
CREATE TABLE skus_master (
    id STRING,
    principal_id BIGINT,
    node_id BIGINT,
    category STRING,
    product STRING,
    product_id STRING,
    category_group STRING,
    sub_brand STRING,
    brand STRING,
    code STRING,
    name STRING,
    short_description STRING,
    description STRING,
    fulfillment_type STRING,
    avg_l0_per_put INT,
    inventory_type STRING,
    shelf_life INT,
    identifier1 STRING,
    identifier2 STRING,
    tag1 STRING,
    tag2 STRING,
    tag3 STRING,
    tag4 STRING,
    tag5 STRING,
    tag6 STRING,
    tag7 STRING,
    tag8 STRING,
    tag9 STRING,
    tag10 STRING,
    handling_unit_type STRING,
    cases_per_layer INT,
    layers INT,
    active_from TIMESTAMP(3),
    active_till TIMESTAMP(3),
    l0_units INT,
    l1_units INT,
    l2_units INT,
    l2_units_final INT,
    l3_units INT,
    l3_units_final INT,
    l0_name STRING,
    l0_weight DOUBLE,
    l0_volume DOUBLE,
    l0_package_type STRING,
    l0_length DOUBLE,
    l0_width DOUBLE,
    l0_height DOUBLE,
    l0_packing_efficiency DOUBLE,
    l0_itf_code STRING,
    l0_erp_weight DOUBLE,
    l0_erp_volume DOUBLE,
    l0_erp_length DOUBLE,
    l0_erp_width DOUBLE,
    l0_erp_height DOUBLE,
    l0_text_tag1 STRING,
    l0_text_tag2 STRING,
    l0_image STRING,
    l0_num_tag1 DOUBLE,
    l1_name STRING,
    l1_weight DOUBLE,
    l1_volume DOUBLE,
    l1_package_type STRING,
    l1_length DOUBLE,
    l1_width DOUBLE,
    l1_height DOUBLE,
    l1_packing_efficiency DOUBLE,
    l1_itf_code STRING,
    l1_erp_weight DOUBLE,
    l1_erp_volume DOUBLE,
    l1_erp_length DOUBLE,
    l1_erp_width DOUBLE,
    l1_erp_height DOUBLE,
    l1_text_tag1 STRING,
    l1_text_tag2 STRING,
    l1_image STRING,
    l1_num_tag1 DOUBLE,
    l2_name STRING,
    l2_weight DOUBLE,
    l2_volume DOUBLE,
    l2_package_type STRING,
    l2_length DOUBLE,
    l2_width DOUBLE,
    l2_height DOUBLE,
    l2_packing_efficiency DOUBLE,
    l2_itf_code STRING,
    l2_erp_weight DOUBLE,
    l2_erp_volume DOUBLE,
    l2_erp_length DOUBLE,
    l2_erp_width DOUBLE,
    l2_erp_height DOUBLE,
    l2_text_tag1 STRING,
    l2_text_tag2 STRING,
    l2_image STRING,
    l2_num_tag1 DOUBLE,
    l3_name STRING,
    l3_weight DOUBLE,
    l3_volume DOUBLE,
    l3_package_type STRING,
    l3_length DOUBLE,
    l3_width DOUBLE,
    l3_height DOUBLE,
    l3_packing_efficiency DOUBLE,
    l3_itf_code STRING,
    l3_erp_weight DOUBLE,
    l3_erp_volume DOUBLE,
    l3_erp_length DOUBLE,
    l3_erp_width DOUBLE,
    l3_erp_height DOUBLE,
    l3_text_tag1 STRING,
    l3_text_tag2 STRING,
    l3_image STRING,
    l3_num_tag1 DOUBLE,
    active BOOLEAN NOT NULL,
    classifications STRING NOT NULL,
    product_classifications STRING NOT NULL,
    created_at TIMESTAMP(3) NOT NULL,
    updated_at TIMESTAMP(3) NOT NULL,
    -- Event time for versioning
    event_time AS COALESCE(updated_at, created_at, TIMESTAMP '1970-01-01 00:00:00'),
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'sbx_uat.encarta.public.skus_master',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'scan.bounded.mode' = 'latest-offset',
    'scan.startup.mode' = 'earliest-offset',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'format' = 'avro-confluent',
    'avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}'
);

-- Create views to get the latest version of each dimension record
-- This prevents cartesian products in joins when not using temporal joins

CREATE VIEW handling_units_latest AS
SELECT * FROM (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY `whId`, id ORDER BY event_time DESC) as rn
    FROM handling_units
) WHERE rn = 1;

CREATE VIEW handling_unit_kinds_latest AS
SELECT * FROM (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY `whId`, id ORDER BY event_time DESC) as rn
    FROM handling_unit_kinds
) WHERE rn = 1;

CREATE VIEW storage_bin_master_latest AS
SELECT * FROM (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY wh_id, bin_id ORDER BY event_time DESC) as rn
    FROM storage_bin_master
) WHERE rn = 1;

CREATE VIEW skus_master_latest AS
SELECT * FROM (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY event_time DESC) as rn
    FROM skus_master
) WHERE rn = 1;

-- Sink: Enriched inventory events
CREATE TABLE inventory_events_enriched (
    -- Event identifiers
    hu_event_id STRING NOT NULL,
    quant_event_id STRING NOT NULL,
    wh_id BIGINT,
    
    -- Handling unit event fields
    hu_event_seq BIGINT,
    hu_id STRING,
    hu_event_type STRING,
    hu_event_timestamp TIMESTAMP(3),
    hu_event_payload STRING,
    hu_event_attrs STRING,
    session_id STRING,
    task_id STRING,
    correlation_id STRING,
    storage_id STRING,
    outer_hu_id STRING,
    effective_storage_id STRING,
    
    -- Handling unit quant event fields
    sku_id STRING,
    uom STRING,
    bucket STRING,
    batch STRING,
    price STRING,
    inclusion_status STRING,
    locked_by_task_id STRING,
    lock_mode STRING,
    qty_added INT,
    
    -- Enriched handling unit fields
    hu_code STRING,
    hu_kind_id STRING,
    hu_state STRING,
    hu_attrs STRING,
    hu_created_at TIMESTAMP(3),
    hu_updated_at TIMESTAMP(3),
    hu_lock_task_id STRING,
    hu_effective_storage_id STRING,
    
    -- Enriched handling unit kind fields
    hu_kind_code STRING,
    hu_kind_name STRING,
    hu_kind_attrs STRING,
    hu_kind_active BOOLEAN,
    hu_kind_max_volume DOUBLE,
    hu_kind_max_weight DOUBLE,
    hu_kind_usage_type STRING,
    hu_kind_abbr STRING,
    hu_kind_length DOUBLE,
    hu_kind_breadth DOUBLE,
    hu_kind_height DOUBLE,
    hu_kind_weight DOUBLE,
    
    -- Enriched storage bin fields
    storage_bin_code STRING,
    storage_bin_description STRING,
    storage_bin_status STRING,
    storage_bin_hu_id STRING,
    storage_multi_sku BOOLEAN,
    storage_multi_batch BOOLEAN,
    storage_picking_position INT,
    storage_putaway_position INT,
    storage_rank INT,
    storage_aisle STRING,
    storage_bay STRING,
    storage_level STRING,
    storage_position STRING,
    storage_depth STRING,
    storage_max_sku_count INT,
    storage_max_sku_batch_count INT,
    storage_bin_type_id STRING,
    storage_bin_type_code STRING,
    storage_bin_type_description STRING,
    storage_max_volume_in_cc DOUBLE,
    storage_max_weight_in_kg DOUBLE,
    storage_pallet_capacity INT,
    storage_hu_type STRING,
    storage_auxiliary_bin BOOLEAN,
    storage_hu_multi_sku BOOLEAN,
    storage_hu_multi_batch BOOLEAN,
    storage_use_derived_pallet_best_fit BOOLEAN,
    storage_only_full_pallet BOOLEAN,
    storage_bin_type_active BOOLEAN,
    storage_zone_id STRING,
    storage_zone_code STRING,
    storage_zone_description STRING,
    storage_zone_face STRING,
    storage_peripheral BOOLEAN,
    storage_surveillance_config STRING,
    storage_zone_active BOOLEAN,
    storage_area_id STRING,
    storage_area_code STRING,
    storage_area_description STRING,
    storage_area_type STRING,
    storage_rolling_days INT,
    storage_area_active BOOLEAN,
    storage_x1 DOUBLE,
    storage_x2 DOUBLE,
    storage_y1 DOUBLE,
    storage_y2 DOUBLE,
    storage_position_active BOOLEAN,
    storage_attrs STRING,
    storage_bin_mapping STRING,
    storage_created_at TIMESTAMP(3),
    storage_updated_at TIMESTAMP(3),
    
    -- Enriched SKU master fields
    sku_code STRING,
    sku_name STRING,
    sku_short_description STRING,
    sku_description STRING,
    sku_category STRING,
    sku_product STRING,
    sku_product_id STRING,
    sku_category_group STRING,
    sku_sub_brand STRING,
    sku_brand STRING,
    sku_fulfillment_type STRING,
    sku_inventory_type STRING,
    sku_shelf_life INT,
    sku_handling_unit_type STRING,
    sku_cases_per_layer INT,
    sku_layers INT,
    sku_active_from TIMESTAMP(3),
    sku_active_till TIMESTAMP(3),
    sku_l0_units INT,
    sku_l0_name STRING,
    sku_l0_weight DOUBLE,
    sku_l0_volume DOUBLE,
    sku_l0_length DOUBLE,
    sku_l0_width DOUBLE,
    sku_l0_height DOUBLE,
    sku_l1_units INT,
    sku_l1_name STRING,
    sku_l1_weight DOUBLE,
    sku_l1_volume DOUBLE,
    sku_l1_length DOUBLE,
    sku_l1_width DOUBLE,
    sku_l1_height DOUBLE,
    sku_active BOOLEAN,
    sku_created_at TIMESTAMP(3),
    sku_updated_at TIMESTAMP(3),
    
    PRIMARY KEY (hu_event_id, quant_event_id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.internal.inventory_events_enriched',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'sink.parallelism' = '4',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'key.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'key.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'value.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'value.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'value.fields-include' = 'ALL'
);

-- Enrichment query using views with latest dimension data
INSERT INTO inventory_events_enriched
SELECT
    /*+ USE_HASH_JOIN */
    -- Event identifiers
    ie.hu_event_id,
    ie.quant_event_id,
    ie.wh_id,
    
    -- Handling unit event fields
    ie.hu_event_seq,
    ie.hu_id,
    ie.hu_event_type,
    ie.hu_event_timestamp,
    ie.hu_event_payload,
    ie.hu_event_attrs,
    ie.session_id,
    ie.task_id,
    ie.correlation_id,
    ie.storage_id,
    ie.outer_hu_id,
    ie.effective_storage_id,
    
    -- Handling unit quant event fields
    ie.sku_id,
    ie.uom,
    ie.bucket,
    ie.batch,
    ie.price,
    ie.inclusion_status,
    ie.locked_by_task_id,
    ie.lock_mode,
    ie.qty_added,
    
    -- Enriched handling unit fields
    COALESCE(hu.code, '') AS hu_code,
    COALESCE(hu.`kindId`, '') AS hu_kind_id,
    COALESCE(hu.state, '') AS hu_state,
    COALESCE(hu.attrs, '') AS hu_attrs,
    hu.`createdAt` AS hu_created_at,
    hu.`updatedAt` AS hu_updated_at,
    COALESCE(hu.`lockTaskId`, '') AS hu_lock_task_id,
    COALESCE(hu.`effectiveStorageId`, '') AS hu_effective_storage_id,
    
    -- Enriched handling unit kind fields
    COALESCE(huk.code, '') AS hu_kind_code,
    COALESCE(huk.name, '') AS hu_kind_name,
    COALESCE(huk.attrs, '') AS hu_kind_attrs,
    COALESCE(huk.active, FALSE) AS hu_kind_active,
    COALESCE(huk.`maxVolume`, 0.0) AS hu_kind_max_volume,
    COALESCE(huk.`maxWeight`, 0.0) AS hu_kind_max_weight,
    COALESCE(huk.`usageType`, '') AS hu_kind_usage_type,
    COALESCE(huk.abbr, '') AS hu_kind_abbr,
    COALESCE(huk.length, 0.0) AS hu_kind_length,
    COALESCE(huk.breadth, 0.0) AS hu_kind_breadth,
    COALESCE(huk.height, 0.0) AS hu_kind_height,
    COALESCE(huk.weight, 0.0) AS hu_kind_weight,
    
    -- Enriched storage bin fields
    COALESCE(sb.bin_code, '') AS storage_bin_code,
    COALESCE(sb.bin_description, '') AS storage_bin_description,
    COALESCE(sb.bin_status, '') AS storage_bin_status,
    COALESCE(sb.bin_hu_id, '') AS storage_bin_hu_id,
    COALESCE(sb.multi_sku, FALSE) AS storage_multi_sku,
    COALESCE(sb.multi_batch, FALSE) AS storage_multi_batch,
    COALESCE(sb.picking_position, 0) AS storage_picking_position,
    COALESCE(sb.putaway_position, 0) AS storage_putaway_position,
    COALESCE(sb.`rank`, 0) AS storage_rank,
    COALESCE(sb.aisle, '') AS storage_aisle,
    COALESCE(sb.bay, '') AS storage_bay,
    COALESCE(sb.level, '') AS storage_level,
    COALESCE(sb.`position`, '') AS storage_position,
    COALESCE(sb.depth, '') AS storage_depth,
    COALESCE(sb.max_sku_count, 0) AS storage_max_sku_count,
    COALESCE(sb.max_sku_batch_count, 0) AS storage_max_sku_batch_count,
    COALESCE(sb.bin_type_id, '') AS storage_bin_type_id,
    COALESCE(sb.bin_type_code, '') AS storage_bin_type_code,
    COALESCE(sb.bin_type_description, '') AS storage_bin_type_description,
    COALESCE(sb.max_volume_in_cc, 0.0) AS storage_max_volume_in_cc,
    COALESCE(sb.max_weight_in_kg, 0.0) AS storage_max_weight_in_kg,
    COALESCE(sb.pallet_capacity, 0) AS storage_pallet_capacity,
    COALESCE(sb.storage_hu_type, '') AS storage_hu_type,
    COALESCE(sb.auxiliary_bin, FALSE) AS storage_auxiliary_bin,
    COALESCE(sb.hu_multi_sku, FALSE) AS storage_hu_multi_sku,
    COALESCE(sb.hu_multi_batch, FALSE) AS storage_hu_multi_batch,
    COALESCE(sb.use_derived_pallet_best_fit, FALSE) AS storage_use_derived_pallet_best_fit,
    COALESCE(sb.only_full_pallet, FALSE) AS storage_only_full_pallet,
    COALESCE(sb.bin_type_active, FALSE) AS storage_bin_type_active,
    COALESCE(sb.zone_id, '') AS storage_zone_id,
    COALESCE(sb.zone_code, '') AS storage_zone_code,
    COALESCE(sb.zone_description, '') AS storage_zone_description,
    COALESCE(sb.zone_face, '') AS storage_zone_face,
    COALESCE(sb.peripheral, FALSE) AS storage_peripheral,
    COALESCE(sb.surveillance_config, '') AS storage_surveillance_config,
    COALESCE(sb.zone_active, FALSE) AS storage_zone_active,
    COALESCE(sb.area_id, '') AS storage_area_id,
    COALESCE(sb.area_code, '') AS storage_area_code,
    COALESCE(sb.area_description, '') AS storage_area_description,
    COALESCE(sb.area_type, '') AS storage_area_type,
    COALESCE(sb.rolling_days, 0) AS storage_rolling_days,
    COALESCE(sb.area_active, FALSE) AS storage_area_active,
    COALESCE(sb.x1, 0.0) AS storage_x1,
    COALESCE(sb.x2, 0.0) AS storage_x2,
    COALESCE(sb.y1, 0.0) AS storage_y1,
    COALESCE(sb.y2, 0.0) AS storage_y2,
    COALESCE(sb.position_active, FALSE) AS storage_position_active,
    COALESCE(sb.attrs, '') AS storage_attrs,
    COALESCE(sb.bin_mapping, '') AS storage_bin_mapping,
    sb.`createdAt` AS storage_created_at,
    sb.`updatedAt` AS storage_updated_at,
    
    -- Enriched SKU master fields
    COALESCE(sku.code, '') AS sku_code,
    COALESCE(sku.name, '') AS sku_name,
    COALESCE(sku.short_description, '') AS sku_short_description,
    COALESCE(sku.description, '') AS sku_description,
    COALESCE(sku.category, '') AS sku_category,
    COALESCE(sku.product, '') AS sku_product,
    COALESCE(sku.product_id, '') AS sku_product_id,
    COALESCE(sku.category_group, '') AS sku_category_group,
    COALESCE(sku.sub_brand, '') AS sku_sub_brand,
    COALESCE(sku.brand, '') AS sku_brand,
    COALESCE(sku.fulfillment_type, '') AS sku_fulfillment_type,
    COALESCE(sku.inventory_type, '') AS sku_inventory_type,
    COALESCE(sku.shelf_life, 0) AS sku_shelf_life,
    COALESCE(sku.handling_unit_type, '') AS sku_handling_unit_type,
    COALESCE(sku.cases_per_layer, 0) AS sku_cases_per_layer,
    COALESCE(sku.layers, 0) AS sku_layers,
    sku.active_from AS sku_active_from,
    sku.active_till AS sku_active_till,
    COALESCE(sku.l0_units, 0) AS sku_l0_units,
    COALESCE(sku.l0_name, '') AS sku_l0_name,
    COALESCE(sku.l0_weight, 0.0) AS sku_l0_weight,
    COALESCE(sku.l0_volume, 0.0) AS sku_l0_volume,
    COALESCE(sku.l0_length, 0.0) AS sku_l0_length,
    COALESCE(sku.l0_width, 0.0) AS sku_l0_width,
    COALESCE(sku.l0_height, 0.0) AS sku_l0_height,
    COALESCE(sku.l1_units, 0) AS sku_l1_units,
    COALESCE(sku.l1_name, '') AS sku_l1_name,
    COALESCE(sku.l1_weight, 0.0) AS sku_l1_weight,
    COALESCE(sku.l1_volume, 0.0) AS sku_l1_volume,
    COALESCE(sku.l1_length, 0.0) AS sku_l1_length,
    COALESCE(sku.l1_width, 0.0) AS sku_l1_width,
    COALESCE(sku.l1_height, 0.0) AS sku_l1_height,
    COALESCE(sku.active, FALSE) AS sku_active,
    sku.created_at AS sku_created_at,
    sku.updated_at AS sku_updated_at
    
FROM inventory_events_basic ie
    -- Regular LEFT JOIN with latest handling units view (no temporal join)
    LEFT JOIN handling_units_latest hu
        ON ie.wh_id = hu.`whId`
        AND ie.hu_id = hu.id
    -- Regular LEFT JOIN with latest handling unit kinds view via handling unit
    LEFT JOIN handling_unit_kinds_latest huk
        ON hu.`whId` = huk.`whId`
        AND hu.`kindId` = huk.id
    -- Regular LEFT JOIN with latest storage bin master view
    LEFT JOIN storage_bin_master_latest sb
        ON ie.wh_id = sb.wh_id
        AND ie.storage_id = sb.bin_id
    -- Regular LEFT JOIN with latest SKUs master view
    LEFT JOIN skus_master_latest sku
        ON ie.sku_id = sku.id;