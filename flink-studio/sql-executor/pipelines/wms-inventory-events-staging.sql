-- Pipeline to stream ${KAFKA_ENV}.wms.public.handling_unit_event joined with ${KAFKA_ENV}.wms.public.handling_unit_quant_event
SET 'pipeline.name' = 'WMS Inventory Events Basic Processing';
SET 'table.exec.sink.not-null-enforcer' = 'drop';
SET 'parallelism.default' = '2';
SET 'table.optimizer.join-reorder-enabled' = 'true';
SET 'table.exec.resource.default-parallelism' = '2';
-- State TTL configuration to prevent unbounded state growth
-- State will be kept for 1 hour after last access
SET 'table.exec.state.ttl' = '3600000';
-- 1 hour in milliseconds
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
    -- nullable
    `taskId` STRING,
    -- nullable
    `correlationId` STRING,
    -- nullable
    `storageId` STRING,
    -- nullable
    `outerHuId` STRING,
    -- nullable
    `effectiveStorageId` STRING -- nullable
) WITH (
    'connector' = 'kafka',
    'topic' = '${KAFKA_ENV}.wms.public.handling_unit_event',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'properties.group.id' = '${KAFKA_ENV}-wms-inventory-events-staging',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'format' = 'avro-confluent',
    'avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
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
    `qtyAdded` INT NOT NULL,
    iloc STRING NOT NULL,
    `timestamp` TIMESTAMP(3) NOT NULL
) WITH (
    'connector' = 'kafka',
    'topic' = '${KAFKA_ENV}.wms.public.handling_unit_quant_event',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'properties.group.id' = '${KAFKA_ENV}-wms-inventory-events-staging',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'format' = 'avro-confluent',
    'avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
    'avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'properties.auto.offset.reset' = 'earliest'
);
-- Sink table for joined inventory events (no watermark since these are events, not CDC tables)
CREATE TABLE inventory_events_staging (
    -- Handling unit event fields (these are always present from the main table)
    event_id STRING NOT NULL,
    wh_id BIGINT NOT NULL,
    seq BIGINT NOT NULL,
    hu_id STRING NOT NULL,
    event_type STRING NOT NULL,
    timestamp TIMESTAMP(3) NOT NULL,
    payload STRING NOT NULL,
    attrs STRING NOT NULL,
    session_id STRING,
    task_id STRING,
    correlation_id STRING,
    storage_id STRING,
    outer_hu_id STRING,
    effective_storage_id STRING,
    -- Handling unit quant event fields (quant_event_id is coalesced to '' for the key)
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
    quant_iloc STRING,
    PRIMARY KEY (event_id, quant_event_id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = '${KAFKA_ENV}.wms.flink.inventory_events_staging',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'properties.auto.offset.reset' = 'earliest',
    'sink.parallelism' = '2',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
    'key.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'key.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
    'value.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'value.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}'
);
-- Join handling unit events with quant events
-- State TTL (1 hour) prevents unbounded growth for both historical and real-time processing
INSERT INTO inventory_events_staging
SELECT -- Handling unit event fields
    hue.id AS event_id,
    hue.`whId` AS wh_id,
    hue.seq AS seq,
    hue.`huId` AS hu_id,
    hue.type AS event_type,
    hue.`timestamp` AS timestamp,
    hue.payload AS payload,
    hue.attrs AS attrs,
    hue.`sessionId` AS session_id,
    hue.`taskId` AS task_id,
    hue.`correlationId` AS correlation_id,
    hue.`storageId` AS storage_id,
    hue.`outerHuId` AS outer_hu_id,
    hue.`effectiveStorageId` AS effective_storage_id,
    -- Handling unit quant event fields
    COALESCE(huqe.id, '') AS quant_event_id,
    huqe.`skuId` AS sku_id,
    huqe.uom AS uom,
    huqe.bucket AS bucket,
    huqe.batch AS batch,
    huqe.price AS price,
    huqe.`inclusionStatus` AS inclusion_status,
    huqe.`lockedByTaskId` AS locked_by_task_id,
    huqe.`lockMode` AS lock_mode,
    huqe.`qtyAdded` AS qty_added,
    huqe.iloc AS quant_iloc
FROM handling_unit_events hue
    LEFT JOIN handling_unit_quant_events huqe ON hue.id = huqe.`huEventId`;