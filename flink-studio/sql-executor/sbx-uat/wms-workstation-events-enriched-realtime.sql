-- Pipeline to enrich workstation events with dimensional data (real-time processing)
-- This pipeline is optimized for processing real-time streaming data

SET 'pipeline.name' = 'WMS Workstation Events Enriched Realtime';
SET 'table.exec.sink.not-null-enforcer' = 'drop';
SET 'parallelism.default' = '4';
SET 'table.optimizer.join-reorder-enabled' = 'false';
SET 'table.exec.resource.default-parallelism' = '4';
SET 'execution.runtime-mode' = 'STREAMING';

-- Performance optimizations for streaming
SET 'taskmanager.memory.managed.fraction' = '0.8';
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '1s';
SET 'table.exec.mini-batch.size' = '5000';
SET 'execution.checkpointing.interval' = '60000';
SET 'execution.checkpointing.timeout' = '300000';
SET 'state.backend.incremental' = 'true';
SET 'state.backend.rocksdb.compression.type' = 'LZ4';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.exec.source.idle-timeout' = '60000';

-- Watermark alignment for coordinated processing
SET 'pipeline.watermark-alignment.group' = 'workstation-events-enriched-realtime';
SET 'pipeline.watermark-alignment.max-drift' = '5 min';
SET 'pipeline.watermark-alignment.update-interval' = '1000';

-- 1. Source Table: Workstation Events Basic
CREATE TABLE workstation_events_basic_source (
    event_type STRING NOT NULL,
    event_source_id STRING NOT NULL,
    event_timestamp TIMESTAMP(3) NOT NULL,
    wh_id BIGINT,
    sku_id STRING,
    hu_id STRING,
    hu_code STRING,
    batch_id STRING,
    user_id STRING,
    task_id STRING,
    session_id STRING,
    bin_id STRING,
    primary_quantity BIGINT,
    secondary_quantity BIGINT,
    tertiary_quantity BIGINT,
    price STRING,
    status_or_bucket STRING,
    reason STRING,
    sub_reason STRING,
    is_snapshot BOOLEAN NOT NULL,
    event_time TIMESTAMP(3) NOT NULL,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' MINUTE
) WITH (
    'connector' = 'kafka',
    'topic' = 'sbx_uat.wms.internal.workstation_events_basic',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.group.id' = 'sbx-uat-wms-workstation-events-enriched',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'scan.startup.mode' = 'latest-offset',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'value.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'value.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}'
);

-- 2. Dimension Table: Handling Units (for temporal join)
CREATE TABLE handling_units (
    whId BIGINT NOT NULL,
    id STRING NOT NULL,
    code STRING,
    kindId STRING,
    sessionId STRING,
    taskId STRING,
    storageId STRING,
    outerHuId STRING,
    state STRING,
    attrs STRING,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    lockTaskId STRING,
    effectiveStorageId STRING,
    `__source_snapshot` STRING,
    event_time AS COALESCE(updatedAt, createdAt, TIMESTAMP '1970-01-01 00:00:00'),
    is_snapshot AS COALESCE(`__source_snapshot` IN (
        'true',
        'first',
        'first_in_data_collection',
        'last_in_data_collection',
        'last'
    ), FALSE),
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.public.handling_unit',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.group.id' = 'sbx-uat-wms-workstation-events-enriched-realtime',
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

-- 3. Dimension Table: Tasks (for temporal join)
CREATE TABLE tasks (
    whId BIGINT NOT NULL,
    id STRING NOT NULL,
    sessionId STRING,
    kind STRING,
    code STRING,
    seq BIGINT,
    state STRING,
    progress STRING,
    attrs STRING,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    `__source_snapshot` STRING,
    event_time AS COALESCE(updatedAt, createdAt, TIMESTAMP '1970-01-01 00:00:00'),
    is_snapshot AS COALESCE(`__source_snapshot` IN (
        'true',
        'first',
        'first_in_data_collection',
        'last_in_data_collection',
        'last'
    ), FALSE),
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.public.task',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.group.id' = 'sbx-uat-wms-workstation-events-enriched-realtime',
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

-- 4. Dimension Table: Sessions (for temporal join)
CREATE TABLE sessions (
    whId BIGINT NOT NULL,
    id STRING NOT NULL,
    kind STRING,
    code STRING,
    attrs STRING,
    state STRING,
    progress STRING,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    `__source_snapshot` STRING,
    event_time AS COALESCE(updatedAt, createdAt, TIMESTAMP '1970-01-01 00:00:00'),
    is_snapshot AS COALESCE(`__source_snapshot` IN (
        'true',
        'first',
        'first_in_data_collection',
        'last_in_data_collection',
        'last'
    ), FALSE),
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.public.session',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.group.id' = 'sbx-uat-wms-workstation-events-enriched-realtime',
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

-- 5. Dimension Table: Storage Bin (for code lookup)
CREATE TABLE storage_bin (
    whId BIGINT NOT NULL,
    id STRING NOT NULL,
    code STRING,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    `__source_snapshot` STRING,
    event_time AS COALESCE(updatedAt, createdAt, TIMESTAMP '1970-01-01 00:00:00'),
    is_snapshot AS COALESCE(`__source_snapshot` IN (
        'true',
        'first',
        'first_in_data_collection',
        'last_in_data_collection',
        'last'
    ), FALSE),
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.public.storage_bin',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.group.id' = 'sbx-uat-wms-workstation-events-enriched-realtime',
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

-- 6. Dimension Table: Storage Bin Master (for detailed bin information)
CREATE TABLE storage_bin_master (
    wh_id BIGINT NOT NULL,
    bin_id STRING,
    bin_code STRING NOT NULL,
    bin_description STRING,
    bin_status STRING,
    bin_hu_id STRING,
    multi_sku BOOLEAN,
    multi_batch BOOLEAN,
    picking_position BIGINT,
    putaway_position BIGINT,
    `rank` BIGINT,
    aisle STRING,
    bay STRING,
    level STRING,
    `position` STRING,
    depth STRING,
    bin_type_code STRING,
    zone_id STRING,
    zone_code STRING,
    zone_description STRING,
    area_id STRING,
    area_code STRING,
    area_description STRING,
    x1 DOUBLE,
    y1 DOUBLE,
    max_volume_in_cc DOUBLE,
    max_weight_in_kg DOUBLE,
    pallet_capacity BIGINT,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    `__source_snapshot` STRING,
    event_time AS COALESCE(updatedAt, createdAt, TIMESTAMP '1970-01-01 00:00:00'),
    is_snapshot AS COALESCE(`__source_snapshot` IN (
        'true',
        'first',
        'first_in_data_collection',
        'last_in_data_collection',
        'last'
    ), FALSE),
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (wh_id, bin_code) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.public.storage_bin_master',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.group.id' = 'sbx-uat-wms-workstation-events-enriched-realtime',
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

-- Sink Table: Enriched workstation events
CREATE TABLE workstation_events_enriched (
    -- Original event fields
    event_type STRING NOT NULL,
    event_source_id STRING NOT NULL,
    event_timestamp TIMESTAMP(3) NOT NULL,
    wh_id BIGINT,
    sku_id STRING,
    hu_id STRING,
    hu_code STRING,
    batch_id STRING,
    user_id STRING,
    task_id STRING,
    session_id STRING,
    bin_id STRING,
    primary_quantity BIGINT,
    secondary_quantity BIGINT,
    tertiary_quantity BIGINT,
    price STRING,
    status_or_bucket STRING,
    reason STRING,
    sub_reason STRING,
    is_snapshot BOOLEAN NOT NULL,
    event_time TIMESTAMP(3) NOT NULL,
    
    -- Enriched handling unit fields (matching actual schema)
    hu_kind_id STRING,
    hu_session_id STRING,
    hu_task_id STRING,
    hu_storage_id STRING,
    hu_outer_hu_id STRING,
    hu_state STRING,
    hu_attrs STRING,
    hu_created_at TIMESTAMP(3),
    hu_updated_at TIMESTAMP(3),
    hu_lock_task_id STRING,
    hu_effective_storage_id STRING,
    
    -- Enriched task fields (matching actual schema)
    task_session_id STRING,
    task_kind STRING,
    task_code STRING,
    task_seq BIGINT,
    task_state STRING,
    task_progress STRING,
    task_attrs STRING,
    task_created_at TIMESTAMP(3),
    task_updated_at TIMESTAMP(3),
    
    -- Enriched session fields (matching actual schema)
    session_kind STRING,
    session_code STRING,
    session_attrs STRING,
    session_state STRING,
    session_progress STRING,
    session_created_at TIMESTAMP(3),
    session_updated_at TIMESTAMP(3),
    
    -- Enriched storage bin fields (subset of available fields)
    bin_code STRING,
    bin_description STRING,
    bin_status STRING,
    bin_hu_id STRING,
    multi_sku BOOLEAN,
    multi_batch BOOLEAN,
    picking_position BIGINT,
    putaway_position BIGINT,
    `rank` BIGINT,
    aisle STRING,
    bay STRING,
    level STRING,
    `position` STRING,
    depth STRING,
    bin_type_code STRING,
    zone_id STRING,
    zone_code STRING,
    zone_description STRING,
    area_id STRING,
    area_code STRING,
    area_description STRING,
    x1 DOUBLE,
    y1 DOUBLE,
    max_volume_in_cc DOUBLE,
    max_weight_in_kg DOUBLE,
    pallet_capacity BIGINT,
    
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (event_source_id, event_type) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.internal.workstation_events_enriched',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'properties.auto.offset.reset' = 'earliest',
    'sink.parallelism' = '4',
    'sink.buffer-flush.max-rows' = '2000',
    'sink.buffer-flush.interval' = '5s',
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

-- Insert enriched data using temporal joins
INSERT INTO workstation_events_enriched
SELECT /*+ USE_HASH_JOIN */
    -- Original event fields
    we.event_type,
    we.event_source_id,
    we.event_timestamp,
    we.wh_id,
    we.sku_id,
    we.hu_id,
    we.hu_code,
    we.batch_id,
    we.user_id,
    we.task_id,
    we.session_id,
    we.bin_id,
    we.primary_quantity,
    we.secondary_quantity,
    we.tertiary_quantity,
    we.price,
    we.status_or_bucket,
    we.reason,
    we.sub_reason,
    we.is_snapshot,
    we.event_time,
    
    -- Enriched handling unit fields
    hu.kindId AS hu_kind_id,
    hu.sessionId AS hu_session_id,
    hu.taskId AS hu_task_id,
    hu.storageId AS hu_storage_id,
    hu.outerHuId AS hu_outer_hu_id,
    hu.state AS hu_state,
    hu.attrs AS hu_attrs,
    hu.createdAt AS hu_created_at,
    hu.updatedAt AS hu_updated_at,
    hu.lockTaskId AS hu_lock_task_id,
    hu.effectiveStorageId AS hu_effective_storage_id,
    
    -- Enriched task fields
    t.sessionId AS task_session_id,
    t.kind AS task_kind,
    t.code AS task_code,
    t.seq AS task_seq,
    t.state AS task_state,
    t.progress AS task_progress,
    t.attrs AS task_attrs,
    t.createdAt AS task_created_at,
    t.updatedAt AS task_updated_at,
    
    -- Enriched session fields
    s.kind AS session_kind,
    s.code AS session_code,
    s.attrs AS session_attrs,
    s.state AS session_state,
    s.progress AS session_progress,
    s.createdAt AS session_created_at,
    s.updatedAt AS session_updated_at,
    
    -- Enriched storage bin fields
    sbm.bin_code,
    sbm.bin_description,
    sbm.bin_status,
    sbm.bin_hu_id,
    sbm.multi_sku,
    sbm.multi_batch,
    sbm.picking_position,
    sbm.putaway_position,
    sbm.`rank`,
    sbm.aisle,
    sbm.bay,
    sbm.level,
    sbm.`position`,
    sbm.depth,
    sbm.bin_type_code,
    sbm.zone_id,
    sbm.zone_code,
    sbm.zone_description,
    sbm.area_id,
    sbm.area_code,
    sbm.area_description,
    sbm.x1,
    sbm.y1,
    sbm.max_volume_in_cc,
    sbm.max_weight_in_kg,
    sbm.pallet_capacity
    
FROM workstation_events_basic_source we
    LEFT JOIN handling_units FOR SYSTEM_TIME AS OF we.event_time AS hu 
        ON we.hu_id = hu.id
    LEFT JOIN tasks FOR SYSTEM_TIME AS OF we.event_time AS t 
        ON we.task_id = t.id
    LEFT JOIN sessions FOR SYSTEM_TIME AS OF we.event_time AS s 
        ON we.session_id = s.id
    LEFT JOIN storage_bin FOR SYSTEM_TIME AS OF we.event_time AS sb 
        ON we.bin_id = sb.id
    LEFT JOIN storage_bin_master FOR SYSTEM_TIME AS OF we.event_time AS sbm 
        ON we.wh_id = sbm.wh_id AND sb.code = sbm.bin_code
WHERE we.event_time > TIMESTAMP '1970-01-01 00:00:00';