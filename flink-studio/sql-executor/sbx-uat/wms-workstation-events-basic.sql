-- Pipeline to combine multiple WMS workstation events into a unified basic view
-- This is the basic pipeline that reads from CDC source tables and creates a unified event stream

SET 'pipeline.name' = 'WMS Workstation Events Basic Processing';
SET 'table.exec.sink.not-null-enforcer' = 'drop';
SET 'parallelism.default' = '2';
SET 'table.optimizer.join-reorder-enabled' = 'true';
SET 'table.exec.resource.default-parallelism' = '2';

-- Performance optimizations
SET 'taskmanager.memory.managed.fraction' = '0.8';
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '1s';
SET 'table.exec.mini-batch.size' = '5000';
SET 'execution.checkpointing.interval' = '600000';
SET 'execution.checkpointing.timeout' = '1800000';
SET 'state.backend.incremental' = 'true';
SET 'state.backend.rocksdb.compression.type' = 'LZ4';

-- 1. Source Table: Receiving Events (inb_receive_item)
CREATE TABLE inb_receive_item (
    whId BIGINT NOT NULL,
    sessionId STRING,
    taskId STRING,
    id STRING NOT NULL,
    skuId STRING,
    uom STRING,
    batch STRING,
    price STRING,
    overallQty INT,
    qty INT,
    parentItemId STRING,
    createdAt TIMESTAMP(3),
    asnVehicleId STRING,
    stagingBinId STRING,
    stagingBinHUId STRING,
    groupId STRING,
    receivedAt TIMESTAMP(3),
    receivedBy STRING,
    receivedQty INT,
    damagedQty INT,
    deactivatedAt TIMESTAMP(3),
    qcPercentage INT,
    huId STRING,
    huCode STRING,
    reason STRING,
    bucket STRING,
    movedAt TIMESTAMP(3),
    movedBy STRING,
    processedAt TIMESTAMP(3),
    huKind STRING,
    receivedHuKind STRING,
    totalHuWeight DOUBLE,
    receivedHuWeight DOUBLE,
    subReason STRING,
    `__source_snapshot` STRING,
    -- Computed fields
    `event_time` AS COALESCE(
        receivedAt,
        createdAt,
        TIMESTAMP '1970-01-01 00:00:00'
    ),
    `is_snapshot` AS COALESCE(`__source_snapshot` IN (
        'true',
        'first',
        'first_in_data_collection',
        'last_in_data_collection',
        'last'
    ), FALSE),
    WATERMARK FOR `event_time` AS `event_time` - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.public.inb_receive_item',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.group.id' = 'sbx-uat-wms-workstation-events-basic',
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

-- 2. Source Table: Loading Events (ob_load_item)
CREATE TABLE ob_load_item (
    whId BIGINT NOT NULL,
    id STRING NOT NULL,
    sessionId STRING,
    taskId STRING,
    tripId STRING,
    skuId STRING,
    skuClass STRING,
    uom STRING,
    qty INT,
    seq BIGINT,
    loadedQty INT,
    loadedAt TIMESTAMP(3),
    loadedBy STRING,
    createdAt TIMESTAMP(3),
    invoiceId STRING,
    skuCategory STRING,
    originalSkuId STRING,
    batch STRING,
    huId STRING,
    huCode STRING,
    mmTripId STRING,
    innerHUId STRING,
    innerHUCode STRING,
    innerHUKind STRING,
    binId STRING,
    binHUId STRING,
    binCode STRING,
    parentItemId STRING,
    classificationType STRING,
    originalQty INT,
    originalUOM STRING,
    repicked BOOLEAN,
    invoiceCode STRING,
    retailerId STRING,
    retailerCode STRING,
    `__source_snapshot` STRING,
    -- Computed fields
    `event_time` AS COALESCE(
        loadedAt,
        createdAt,
        TIMESTAMP '1970-01-01 00:00:00'
    ),
    `is_snapshot` AS COALESCE(`__source_snapshot` IN (
        'true',
        'first',
        'first_in_data_collection',
        'last_in_data_collection',
        'last'
    ), FALSE),
    WATERMARK FOR `event_time` AS `event_time` - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.public.ob_load_item',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.group.id' = 'sbx-uat-wms-workstation-events-basic',
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

-- 3. Source Table: Palletization Events (inb_palletization_item)
CREATE TABLE inb_palletization_item (
    id STRING NOT NULL,
    whId BIGINT NOT NULL,
    sessionId STRING,
    taskId STRING,
    skuId STRING,
    batch STRING,
    price STRING,
    uom STRING,
    bucket STRING,
    qty INT,
    huId STRING,
    huCode STRING,
    outerHUId STRING,
    outerHUCode STRING,
    serializationItemId STRING,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    mappedAt TIMESTAMP(3),
    mappedBy STRING,
    reason STRING,
    stagingBinId STRING,
    stagingBinHuId STRING,
    asnId STRING,
    asnNo STRING,
    initialBucket STRING,
    qtyInside INT,
    uomInside STRING,
    subReason STRING,
    deactivatedAt TIMESTAMP(3),
    `__source_snapshot` STRING,
    -- Computed fields
    `event_time` AS COALESCE(
        mappedAt,
        updatedAt,
        createdAt,
        TIMESTAMP '1970-01-01 00:00:00'
    ),
    `is_snapshot` AS COALESCE(`__source_snapshot` IN (
        'true',
        'first',
        'first_in_data_collection',
        'last_in_data_collection',
        'last'
    ), FALSE),
    WATERMARK FOR `event_time` AS `event_time` - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.public.inb_palletization_item',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.group.id' = 'sbx-uat-wms-workstation-events-basic',
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

-- 4. Source Table: Serialization Events (inb_serialization_item)
CREATE TABLE inb_serialization_item (
    id STRING NOT NULL,
    whId BIGINT NOT NULL,
    sessionId STRING,
    taskId STRING,
    skuId STRING,
    batch STRING,
    uom STRING,
    qty INT,
    huId STRING,
    huCode STRING,
    createdAt TIMESTAMP(3),
    serializedAt TIMESTAMP(3),
    serializedBy STRING,
    bucket STRING,
    stagingBinId STRING,
    stagingBinHuId STRING,
    qtyInside INT,
    printLabel STRING,
    preparedAt TIMESTAMP(3),
    preparedBy STRING,
    uomInside STRING,
    reason STRING,
    subReason STRING,
    reasonUpdatedAt TIMESTAMP(3),
    reasonUpdatedBy STRING,
    mode STRING,
    rejected BOOLEAN,
    deactivatedAt TIMESTAMP(3),
    `__source_snapshot` STRING,
    -- Computed fields
    `event_time` AS COALESCE(
        serializedAt,
        createdAt,
        TIMESTAMP '1970-01-01 00:00:00'
    ),
    `is_snapshot` AS COALESCE(`__source_snapshot` IN (
        'true',
        'first',
        'first_in_data_collection',
        'last_in_data_collection',
        'last'
    ), FALSE),
    WATERMARK FOR `event_time` AS `event_time` - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.public.inb_serialization_item',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.group.id' = 'sbx-uat-wms-workstation-events-basic',
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

-- 5. Source Table: QC Events (inb_qc_item_v2)
CREATE TABLE inb_qc_item_v2 (
    id STRING NOT NULL,
    whId BIGINT NOT NULL,
    sessionId STRING,
    taskId STRING,
    skuId STRING,
    uom STRING,
    batch STRING,
    bucket STRING,
    price STRING,
    qty INT,
    receivedQty INT,
    sampleSize INT,
    inspectionLevel STRING,
    acceptableIssueSize INT,
    actualSkuId STRING,
    actualUom STRING,
    actualBatch STRING,
    actualPrice STRING,
    actualBucket STRING,
    actualQty INT,
    actualQtyInside INT,
    parentItemId STRING,
    createdAt TIMESTAMP(3),
    createdBy STRING,
    deactivatedAt TIMESTAMP(3),
    deactivatedBy STRING,
    updatedAt TIMESTAMP(3),
    movedAt TIMESTAMP(3),
    movedBy STRING,
    movedQty INT,
    processedAt TIMESTAMP(3),
    uomInside STRING,
    reason STRING,
    subReason STRING,
    batchOverridden STRING,
    `__source_snapshot` STRING,
    -- Computed fields
    `event_time` AS COALESCE(
        createdAt,
        updatedAt,
        TIMESTAMP '1970-01-01 00:00:00'
    ),
    `is_snapshot` AS COALESCE(`__source_snapshot` IN (
        'true',
        'first',
        'first_in_data_collection',
        'last_in_data_collection',
        'last'
    ), FALSE),
    WATERMARK FOR `event_time` AS `event_time` - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.public.inb_qc_item_v2',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.group.id' = 'sbx-uat-wms-workstation-events-basic',
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

-- 6. Source Table: Inventory Adjustment Events (ira_bin_items)
CREATE TABLE ira_bin_items (
    id STRING NOT NULL,
    whId BIGINT NOT NULL,
    sessionId STRING,
    taskId STRING,
    binId STRING,
    skuId STRING,
    uom STRING,
    systemQty INT,
    systemDamagedQty INT,
    physicalQty INT,
    physicalDamagedQty INT,
    finalQty INT,
    finalDamagedQty INT,
    issue STRING,
    state STRING,
    createdAt TIMESTAMP(3),
    scannedAt TIMESTAMP(3),
    scannedBy STRING,
    approvedAt TIMESTAMP(3),
    approvedBy STRING,
    batch STRING,
    processedAt TIMESTAMP(3),
    sourceHUId STRING,
    sourceHUCode STRING,
    transactionId STRING,
    binStorageHUType STRING,
    deactivatedAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    updatedBy STRING,
    huSameBinBeforeIRA STRING,
    recordNo INT,
    hlrStatus STRING,
    `__source_snapshot` STRING,
    -- Computed fields
    `event_time` AS COALESCE(
        scannedAt,
        createdAt,
        updatedAt,
        TIMESTAMP '1970-01-01 00:00:00'
    ),
    `is_snapshot` AS COALESCE(`__source_snapshot` IN (
        'true',
        'first',
        'first_in_data_collection',
        'last_in_data_collection',
        'last'
    ), FALSE),
    WATERMARK FOR `event_time` AS `event_time` - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.public.ira_bin_items',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.group.id' = 'sbx-uat-wms-workstation-events-basic',
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

-- 7. Source Table: Outbound QA Events (ob_qa_lineitem)
CREATE TABLE ob_qa_lineitem (
    id STRING NOT NULL,
    whId BIGINT NOT NULL,
    sessionId STRING,
    taskId STRING,
    invoiceId STRING,
    invoiceCode STRING,
    skuId STRING,
    skuClass STRING,
    skuCategory STRING,
    uom STRING,
    orderedQty INT,
    pickedQty INT,
    packedQty INT,
    createdAt TIMESTAMP(3),
    updatedAt TIMESTAMP(3),
    updatedBy STRING,
    tripId STRING,
    tripCode STRING,
    batch STRING,
    retailerId STRING,
    retailerCode STRING,
    `__source_snapshot` STRING,
    -- Computed fields
    `event_time` AS COALESCE(
        createdAt,
        updatedAt,
        TIMESTAMP '1970-01-01 00:00:00'
    ),
    `is_snapshot` AS COALESCE(`__source_snapshot` IN (
        'true',
        'first',
        'first_in_data_collection',
        'last_in_data_collection',
        'last'
    ), FALSE),
    WATERMARK FOR `event_time` AS `event_time` - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.public.ob_qa_lineitem',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.group.id' = 'sbx-uat-wms-workstation-events-basic',
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

-- Sink Table: Unified workstation events (basic)
CREATE TABLE workstation_events_basic (
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
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (event_source_id, event_type) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.wms.internal.workstation_events_basic',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'properties.auto.offset.reset' = 'earliest',
    'sink.parallelism' = '2',
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

-- Insert data into sink table
INSERT INTO workstation_events_basic
-- 1. Receiving Events
SELECT 'RECEIVING' AS event_type,
    iri.id AS event_source_id,
    iri.createdAt AS event_timestamp,
    iri.whId AS wh_id,
    iri.skuId AS sku_id,
    iri.huId AS hu_id,
    iri.huCode AS hu_code,
    iri.batch AS batch_id,
    iri.receivedBy AS user_id,
    iri.taskId AS task_id,
    iri.sessionId AS session_id,
    iri.stagingBinId AS bin_id,
    CAST(iri.receivedQty AS BIGINT) AS primary_quantity,
    CAST(iri.overallQty AS BIGINT) AS secondary_quantity,
    CAST(iri.damagedQty AS BIGINT) AS tertiary_quantity,
    iri.price AS price,
    iri.reason AS status_or_bucket,
    iri.reason AS reason,
    iri.subReason AS sub_reason,
    iri.is_snapshot AS is_snapshot,
    iri.event_time AS event_time
FROM inb_receive_item iri
WHERE iri.event_time > TIMESTAMP '1970-01-01 00:00:00'

UNION ALL

-- 2. Loading Events
SELECT 'LOADING' AS event_type,
    oli.id AS event_source_id,
    oli.loadedAt AS event_timestamp,
    oli.whId AS wh_id,
    oli.skuId AS sku_id,
    oli.huId AS hu_id,
    oli.huCode AS hu_code,
    oli.batch AS batch_id,
    oli.loadedBy AS user_id,
    oli.taskId AS task_id,
    oli.sessionId AS session_id,
    oli.binId AS bin_id,
    CAST(oli.loadedQty AS BIGINT) AS primary_quantity,
    CAST(oli.qty AS BIGINT) AS secondary_quantity,
    CAST(0 AS BIGINT) AS tertiary_quantity,
    CAST(NULL AS STRING) AS price,
    oli.classificationType AS status_or_bucket,
    CAST(NULL AS STRING) AS reason,
    CAST(NULL AS STRING) AS sub_reason,
    oli.is_snapshot AS is_snapshot,
    oli.event_time AS event_time
FROM ob_load_item oli
WHERE oli.event_time > TIMESTAMP '1970-01-01 00:00:00'

UNION ALL

-- 3. Palletization Events
SELECT 'PALLETIZATION' AS event_type,
    ipi.id AS event_source_id,
    ipi.mappedAt AS event_timestamp,
    ipi.whId AS wh_id,
    ipi.skuId AS sku_id,
    ipi.huId AS hu_id,
    ipi.huCode AS hu_code,
    ipi.batch AS batch_id,
    ipi.mappedBy AS user_id,
    ipi.taskId AS task_id,
    ipi.sessionId AS session_id,
    ipi.stagingBinId AS bin_id,
    CAST(ipi.qty AS BIGINT) AS primary_quantity,
    CAST(ipi.qtyInside AS BIGINT) AS secondary_quantity,
    CAST(0 AS BIGINT) AS tertiary_quantity,
    ipi.price AS price,
    ipi.bucket AS status_or_bucket,
    ipi.reason AS reason,
    ipi.subReason AS sub_reason,
    ipi.is_snapshot AS is_snapshot,
    ipi.event_time AS event_time
FROM inb_palletization_item ipi
WHERE ipi.event_time > TIMESTAMP '1970-01-01 00:00:00'

UNION ALL

-- 4. Serialization Events
SELECT 'INBOUND_SERIALIZATION' AS event_type,
    isi.id AS event_source_id,
    isi.serializedAt AS event_timestamp,
    isi.whId AS wh_id,
    isi.skuId AS sku_id,
    isi.huId AS hu_id,
    isi.huCode AS hu_code,
    isi.batch AS batch_id,
    isi.serializedBy AS user_id,
    isi.taskId AS task_id,
    isi.sessionId AS session_id,
    isi.stagingBinId AS bin_id,
    CAST(isi.qty AS BIGINT) AS primary_quantity,
    CAST(isi.qtyInside AS BIGINT) AS secondary_quantity,
    CAST(0 AS BIGINT) AS tertiary_quantity,
    CAST(NULL AS STRING) AS price,
    isi.bucket AS status_or_bucket,
    isi.reason AS reason,
    isi.subReason AS sub_reason,
    isi.is_snapshot AS is_snapshot,
    isi.event_time AS event_time
FROM inb_serialization_item isi
WHERE isi.event_time > TIMESTAMP '1970-01-01 00:00:00'

UNION ALL

-- 5. QC Events
SELECT 'INBOUND_QC' AS event_type,
    iqci2.id AS event_source_id,
    iqci2.createdAt AS event_timestamp,
    iqci2.whId AS wh_id,
    iqci2.skuId AS sku_id,
    iqci2.parentItemId AS hu_id,
    CAST(NULL AS STRING) AS hu_code,
    iqci2.batch AS batch_id,
    iqci2.createdBy AS user_id,
    iqci2.taskId AS task_id,
    iqci2.sessionId AS session_id,
    CAST(NULL AS STRING) AS bin_id,
    CAST(iqci2.actualQty AS BIGINT) AS primary_quantity,
    CAST(iqci2.receivedQty AS BIGINT) AS secondary_quantity,
    CAST(0 AS BIGINT) AS tertiary_quantity,
    iqci2.price AS price,
    iqci2.bucket AS status_or_bucket,
    iqci2.reason AS reason,
    iqci2.subReason AS sub_reason,
    iqci2.is_snapshot AS is_snapshot,
    iqci2.event_time AS event_time
FROM inb_qc_item_v2 iqci2
WHERE iqci2.event_time > TIMESTAMP '1970-01-01 00:00:00'

UNION ALL

-- 6. Inventory Adjustment Events
SELECT 'INVENTORY_ADJUSTMENT' AS event_type,
    ibi.id AS event_source_id,
    ibi.scannedAt AS event_timestamp,
    ibi.whId AS wh_id,
    ibi.skuId AS sku_id,
    ibi.sourceHUId AS hu_id,
    ibi.sourceHUCode AS hu_code,
    ibi.batch AS batch_id,
    ibi.scannedBy AS user_id,
    ibi.taskId AS task_id,
    ibi.sessionId AS session_id,
    ibi.binId AS bin_id,
    CAST(ibi.physicalQty AS BIGINT) AS primary_quantity,
    CAST(ibi.systemQty AS BIGINT) AS secondary_quantity,
    CAST(ibi.physicalDamagedQty AS BIGINT) AS tertiary_quantity,
    CAST(NULL AS STRING) AS price,
    ibi.state AS status_or_bucket,
    ibi.issue AS reason,
    CAST(NULL AS STRING) AS sub_reason,
    ibi.is_snapshot AS is_snapshot,
    ibi.event_time AS event_time
FROM ira_bin_items ibi
WHERE ibi.event_time > TIMESTAMP '1970-01-01 00:00:00'

UNION ALL

-- 7. Outbound QA Events
SELECT 'OUTBOUND_QA' AS event_type,
    oq.id AS event_source_id,
    oq.createdAt AS event_timestamp,
    oq.whId AS wh_id,
    oq.skuId AS sku_id,
    CAST(NULL AS STRING) AS hu_id,
    CAST(NULL AS STRING) AS hu_code,
    oq.batch AS batch_id,
    oq.updatedBy AS user_id,
    oq.taskId AS task_id,
    oq.sessionId AS session_id,
    CAST(NULL AS STRING) AS bin_id,
    CAST(oq.pickedQty AS BIGINT) AS primary_quantity,
    CAST(oq.packedQty AS BIGINT) AS secondary_quantity,
    CAST(oq.orderedQty AS BIGINT) AS tertiary_quantity,
    CAST(NULL AS STRING) AS price,
    oq.skuCategory AS status_or_bucket,
    oq.skuClass AS reason,
    oq.uom AS sub_reason,
    oq.is_snapshot AS is_snapshot,
    oq.event_time AS event_time
FROM ob_qa_lineitem oq
WHERE oq.event_time > TIMESTAMP '1970-01-01 00:00:00';