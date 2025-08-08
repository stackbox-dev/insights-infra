-- Pipeline to stream sbx_uat.wms.public.handling_unit_event interval joined with sbx_uat.wms.public.handling_unit_quant_event (5 minutes)

SET 'pipeline.name' = 'WMS Inventory Events Basic Processing';
SET 'table.exec.sink.not-null-enforcer' = 'drop';
SET 'parallelism.default' = '2';
SET 'table.optimizer.join-reorder-enabled' = 'true';
SET 'table.exec.resource.default-parallelism' = '2';

-- State TTL configuration to prevent unbounded state growth
-- State will be kept for 1 hour after last access
SET 'table.exec.state.ttl' = '3600000'; -- 1 hour in milliseconds

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

-- Source Table 1: Handling Unit Events
CREATE TABLE handling_unit_events (
    `whId` BIGINT NOT NULL,
    id STRING NOT NULL,
    seq BIGINT NOT NULL,
    `huId` STRING NOT NULL,
    type STRING NOT NULL,
    `timestamp` TIMESTAMP(3) NOT NULL,
    payload STRING NOT NULL,
    attrs STRING NOT NULL,
    `sessionId` STRING,
    `taskId` STRING,
    `correlationId` STRING,
    `storageId` STRING,
    `outerHuId` STRING,
    `effectiveStorageId` STRING,
    WATERMARK FOR `timestamp` AS `timestamp` - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'sbx_uat.wms.public.handling_unit_event',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.group.id' = 'sbx-uat-wms-inventory-events-basic',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'format' = 'avro-confluent',
    'avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'properties.auto.offset.reset' = 'earliest'
);

-- Source Table 2: Handling Unit Quant Events
-- Note: These events are created alongside handling_unit_events but arrive separately
-- Since they lack timestamps, we rely on Kafka offset ordering and arrival time
CREATE TABLE handling_unit_quant_events (
    `whId` BIGINT NOT NULL,
    id STRING NOT NULL,
    `huEventId` STRING NOT NULL,
    `skuId` STRING NOT NULL,
    uom STRING NOT NULL,
    bucket STRING NOT NULL,
    batch STRING NOT NULL,
    price STRING NOT NULL,
    `inclusionStatus` STRING NOT NULL,
    `lockedByTaskId` STRING NOT NULL,
    `lockMode` STRING NOT NULL,
    `qtyAdded` INT NOT NULL
) WITH (
    'connector' = 'kafka',
    'topic' = 'sbx_uat.wms.public.handling_unit_quant_event',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.group.id' = 'sbx-uat-wms-inventory-events-basic',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'format' = 'avro-confluent',
    'avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'properties.auto.offset.reset' = 'earliest'
);

-- Sink table for joined inventory events
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
    WATERMARK FOR hu_event_timestamp AS hu_event_timestamp - INTERVAL '5' SECOND,
    PRIMARY KEY (hu_event_id, quant_event_id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.internal.inventory_events_basic',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'properties.auto.offset.reset' = 'earliest',
    'sink.parallelism' = '2',
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

-- Join handling unit events with quant events
-- State TTL (1 hour) prevents unbounded growth for both historical and real-time processing
INSERT INTO inventory_events_basic
SELECT
    /*+ USE_HASH_JOIN */
    -- Handling unit event fields
    hue.id AS hu_event_id,
    hue.`whId` AS wh_id,
    hue.seq AS hu_event_seq,
    hue.`huId` AS hu_id,
    hue.type AS hu_event_type,
    hue.`timestamp` AS hu_event_timestamp,
    hue.payload AS hu_event_payload,
    hue.attrs AS hu_event_attrs,
    hue.`sessionId` AS session_id,
    hue.`taskId` AS task_id,
    hue.`correlationId` AS correlation_id,
    hue.`storageId` AS storage_id,
    hue.`outerHuId` AS outer_hu_id,
    hue.`effectiveStorageId` AS effective_storage_id,
    -- Handling unit quant event fields
    COALESCE(huqe.id, '') AS quant_event_id,
    COALESCE(huqe.`skuId`, '') AS sku_id,
    COALESCE(huqe.uom, '') AS uom,
    COALESCE(huqe.bucket, '') AS bucket,
    COALESCE(huqe.batch, '') AS batch,
    COALESCE(huqe.price, '') AS price,
    COALESCE(huqe.`inclusionStatus`, '') AS inclusion_status,
    COALESCE(huqe.`lockedByTaskId`, '') AS locked_by_task_id,
    COALESCE(huqe.`lockMode`, '') AS lock_mode,
    COALESCE(huqe.`qtyAdded`, 0) AS qty_added
FROM handling_unit_events hue
    -- Regular left join on foreign key relationship
    -- State TTL configuration ensures state is cleaned up after 1 hour
    LEFT JOIN handling_unit_quant_events huqe 
        ON hue.id = huqe.`huEventId`
        AND hue.`whId` = huqe.`whId`;