SET 'pipeline.name' = 'Encarta SKUs Master';
-- Parallelism configuration  
SET 'parallelism.default' = '6';
SET 'pipeline.max-parallelism' = '6';
-- Table optimizer configuration
SET 'table.optimizer.join-reorder-enabled' = 'true';
SET 'table.optimizer.agg-phase-strategy' = 'AUTO';
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '2s';
SET 'table.exec.mini-batch.size' = '2000';
-- Join optimization
SET 'table.optimizer.distinct-agg.split.enabled' = 'true';
SET 'table.exec.spill-compression.enabled' = 'true';
SET 'table.exec.spill-compression.block-size' = '64kb';
-- Memory and state optimization
SET 'taskmanager.memory.managed.fraction' = '0.7';
-- Increased for better state backend performance
SET 'table.exec.state.ttl' = '86400000';
-- 24 hours in ms
SET 'state.backend.rocksdb.block.cache-size' = '512mb';
-- Increased cache for better performance
-- Advanced RocksDB optimization
SET 'state.backend.rocksdb.writebuffer.size' = '256mb';
-- Increased for better write performance
SET 'state.backend.rocksdb.writebuffer.count' = '3';
-- Reduced to avoid too much memory usage
SET 'state.backend.rocksdb.writebuffer.number-to-merge' = '1';
-- Reduced for faster merging
SET 'state.backend.rocksdb.compaction.style' = 'LEVEL';
SET 'state.backend.rocksdb.compaction.level.max-size-level-base' = '512mb';
-- Increased for better compaction
SET 'state.backend.rocksdb.use-bloom-filter' = 'true';
SET 'state.backend.rocksdb.bloom-filter.bits-per-key' = '10';
-- Additional RocksDB checkpoint optimizations
SET 'state.backend.rocksdb.checkpoint.transfer.thread-num' = '4';
SET 'state.backend.rocksdb.restore.thread-num' = '4';
-- Checkpoint optimization
SET 'execution.checkpointing.interval' = '120000';
-- 2 minutes (increased for complex joins)
SET 'execution.checkpointing.min-pause' = '60000';
-- 1 minute (increased to reduce pressure)
SET 'execution.checkpointing.timeout' = '900000';
-- 15 minutes (increased for large state)
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
-- Ensure only one checkpoint at a time
SET 'execution.checkpointing.tolerable-failed-checkpoints' = '3';
-- Allow some failures before job fails
-- Network and I/O optimization
SET 'taskmanager.network.memory.fraction' = '0.15';
SET 'taskmanager.network.memory.max' = '1gb';
SET 'table.exec.resource.default-parallelism' = '6';
-- JSON and sink optimization
SET 'table.exec.legacy-cast-behaviour' = 'disabled';
SET 'table.exec.sink.upsert-materialize' = 'auto';
-- Source optimization
SET 'table.exec.source.idle-timeout' = '30000';
-- 30 seconds
SET 'scan.startup.mode' = 'group-offsets';
-- Use consumer group offsets
-- Kafka consumer optimization
SET 'properties.fetch.min.bytes' = '1024';
SET 'properties.fetch.max.wait.ms' = '500';
SET 'properties.max.poll.records' = '500';
SET 'properties.receive.buffer.bytes' = '65536';
SET 'properties.send.buffer.bytes' = '131072';
-- Advanced memory tuning
SET 'taskmanager.memory.process.size' = '4gb';
SET 'taskmanager.memory.flink.size' = '3.2gb';
-- Removed conflicting managed.size setting to avoid conflicts with fraction
-- JOIN optimization hints
SET 'table.optimizer.join.broadcast-threshold' = '10MB';
SET 'table.optimizer.multiple-input-enabled' = 'true';
SET 'table.exec.operator-fusion-codegen.enabled' = 'true';
-- Avro serialization optimization
SET 'avro-confluent.schema.cache-size' = '1000';
SET 'properties.compression.type' = 'snappy';
-- =====================================================
-- SOURCE TABLES (Kafka Topics)
-- =====================================================
-- skus source table
CREATE TABLE skus (
    id STRING,
    principal_id BIGINT,
    code STRING,
    name STRING,
    description STRING,
    short_description STRING,
    product_id STRING,
    ingredients STRING,
    shelf_life INT,
    fulfillment_type STRING,
    active_from TIMESTAMP(3),
    active_till TIMESTAMP(3),
    active BOOLEAN,
    identifier1 STRING,
    identifier2 STRING,
    invoice_life INT,
    avg_l0_per_put INT,
    inventory_type STRING,
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
    layers INT,
    cases_per_layer INT,
    handling_unit_type STRING,
    batch_date_print_level STRING,
    is_deleted BOOLEAN,
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    proc_time AS PROCTIME(),
    event_time AS CASE
        WHEN updated_at > created_at THEN updated_at
        ELSE created_at
    END,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.encarta.public.skus',
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
-- uoms source table
CREATE TABLE uoms (
    id VARCHAR NOT NULL,
    principal_id BIGINT NOT NULL,
    sku_id VARCHAR NOT NULL,
    name VARCHAR,
    hierarchy VARCHAR NOT NULL,
    weight DOUBLE PRECISION,
    volume DOUBLE PRECISION,
    package_type VARCHAR,
    length DOUBLE PRECISION,
    width DOUBLE PRECISION,
    height DOUBLE PRECISION,
    units INT,
    packing_efficiency DOUBLE PRECISION,
    active BOOLEAN,
    itf_code VARCHAR,
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    erp_weight DOUBLE PRECISION,
    erp_volume DOUBLE PRECISION,
    erp_length DOUBLE PRECISION,
    erp_width DOUBLE PRECISION,
    erp_height DOUBLE PRECISION,
    text_tag1 VARCHAR,
    text_tag2 VARCHAR,
    image VARCHAR,
    num_tag1 DOUBLE PRECISION,
    is_deleted BOOLEAN,
    PRIMARY KEY (id) NOT ENFORCED,
    WATERMARK FOR created_at AS created_at - INTERVAL '5' SECOND
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.encarta.public.uoms',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'properties.auto.offset.reset' = 'earliest',
    'properties.allow.auto.create.topics' = 'true',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'key.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'key.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'value.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'value.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}'
);
-- classifications source table
CREATE TABLE classifications (
    id VARCHAR NOT NULL,
    principal_id BIGINT NOT NULL,
    sku_id VARCHAR NOT NULL,
    type VARCHAR NOT NULL,
    `value` VARCHAR,
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    is_deleted BOOLEAN,
    PRIMARY KEY (id) NOT ENFORCED,
    WATERMARK FOR created_at AS created_at - INTERVAL '5' SECOND
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.encarta.public.classifications',
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
-- product_classifications source table
CREATE TABLE t_product_classifications (
    id VARCHAR NOT NULL,
    principal_id BIGINT NOT NULL,
    product_id VARCHAR NOT NULL,
    type VARCHAR NOT NULL,
    `value` VARCHAR,
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    is_deleted BOOLEAN,
    PRIMARY KEY (id) NOT ENFORCED,
    WATERMARK FOR created_at AS created_at - INTERVAL '5' SECOND
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.encarta.public.product_classifications',
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
-- products source table
CREATE TABLE products (
    id STRING,
    principal_id BIGINT,
    code STRING,
    name STRING,
    description STRING,
    sub_category_id STRING,
    sub_brand_id STRING,
    dangerous BOOLEAN,
    spillable BOOLEAN,
    fragile BOOLEAN,
    flammable BOOLEAN,
    alcohol BOOLEAN,
    temperature_controlled BOOLEAN,
    temp_min DOUBLE,
    temp_max DOUBLE,
    cold_chain BOOLEAN,
    shelf_life INT,
    invoice_life INT,
    active BOOLEAN,
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    is_deleted BOOLEAN,
    proc_time AS PROCTIME(),
    event_time AS CASE
        WHEN updated_at > created_at THEN updated_at
        ELSE created_at
    END,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.encarta.public.products',
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
-- categories source table
CREATE TABLE categories (
    id STRING,
    principal_id BIGINT,
    category_group_id STRING,
    code STRING,
    name STRING,
    description STRING,
    active BOOLEAN,
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    is_deleted BOOLEAN,
    proc_time AS PROCTIME(),
    event_time AS CASE
        WHEN updated_at > created_at THEN updated_at
        ELSE created_at
    END,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.encarta.public.categories',
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
-- sub_categories source table
CREATE TABLE sub_categories (
    id STRING,
    principal_id BIGINT,
    category_id STRING,
    code STRING,
    name STRING,
    description STRING,
    active BOOLEAN,
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    is_deleted BOOLEAN,
    proc_time AS PROCTIME(),
    event_time AS CASE
        WHEN updated_at > created_at THEN updated_at
        ELSE created_at
    END,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.encarta.public.sub_categories',
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
-- category_groups source table
CREATE TABLE category_groups (
    id STRING,
    principal_id BIGINT,
    code STRING,
    name STRING,
    description STRING,
    active BOOLEAN,
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    is_deleted BOOLEAN,
    proc_time AS PROCTIME(),
    event_time AS CASE
        WHEN updated_at > created_at THEN updated_at
        ELSE created_at
    END,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.encarta.public.category_groups',
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
-- brands source table
CREATE TABLE brands (
    id STRING,
    principal_id BIGINT,
    code STRING,
    name STRING,
    description STRING,
    active BOOLEAN,
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    is_deleted BOOLEAN,
    proc_time AS PROCTIME(),
    event_time AS CASE
        WHEN updated_at > created_at THEN updated_at
        ELSE created_at
    END,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.encarta.public.brands',
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
-- sub_brands source table
CREATE TABLE sub_brands (
    id STRING,
    principal_id BIGINT,
    brand_id STRING,
    code STRING,
    name STRING,
    description STRING,
    active BOOLEAN,
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    is_deleted BOOLEAN,
    proc_time AS PROCTIME(),
    event_time AS CASE
        WHEN updated_at > created_at THEN updated_at
        ELSE created_at
    END,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.encarta.public.sub_brands',
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
-- =====================================================
-- FINAL DESTINATION TABLE (Kafka Topic)
-- =====================================================
CREATE TABLE skus_master (
    id VARCHAR NOT NULL,
    principal_id BIGINT,
    code VARCHAR,
    name VARCHAR,
    description VARCHAR,
    short_description VARCHAR,
    product_id VARCHAR,
    ingredients VARCHAR,
    shelf_life INT,
    fulfillment_type VARCHAR,
    active_from TIMESTAMP(3),
    active_till TIMESTAMP(3),
    identifier1 VARCHAR,
    identifier2 VARCHAR,
    invoice_life INT,
    avg_l0_per_put INT,
    inventory_type VARCHAR,
    tag1 VARCHAR,
    tag2 VARCHAR,
    tag3 VARCHAR,
    tag4 VARCHAR,
    tag5 VARCHAR,
    tag6 VARCHAR,
    tag7 VARCHAR,
    tag8 VARCHAR,
    tag9 VARCHAR,
    tag10 VARCHAR,
    layers INT,
    cases_per_layer INT,
    handling_unit_type VARCHAR,
    batch_date_print_level VARCHAR,
    product_code VARCHAR,
    product_name VARCHAR,
    product_description VARCHAR,
    dangerous BOOLEAN,
    spillable BOOLEAN,
    fragile BOOLEAN,
    flammable BOOLEAN,
    alcohol BOOLEAN,
    temperature_controlled BOOLEAN,
    temp_min DOUBLE,
    temp_max DOUBLE,
    cold_chain BOOLEAN,
    product_shelf_life INT,
    product_invoice_life INT,
    sub_category_id VARCHAR,
    sub_category_code VARCHAR,
    sub_category_name VARCHAR,
    sub_category_description VARCHAR,
    category_id VARCHAR,
    category_code VARCHAR,
    category_name VARCHAR,
    category_description VARCHAR,
    category_group_id VARCHAR,
    category_group_code VARCHAR,
    category_group_name VARCHAR,
    category_group_description VARCHAR,
    sub_brand_id VARCHAR,
    sub_brand_code VARCHAR,
    sub_brand_name VARCHAR,
    sub_brand_description VARCHAR,
    brand_id VARCHAR,
    brand_code VARCHAR,
    brand_name VARCHAR,
    brand_description VARCHAR,
    l0_units INT,
    l1_units INT,
    l2_units INT,
    l3_units INT,
    l0_name VARCHAR,
    l0_weight DOUBLE PRECISION,
    l0_volume DOUBLE PRECISION,
    l0_package_type VARCHAR,
    l0_length DOUBLE PRECISION,
    l0_width DOUBLE PRECISION,
    l0_height DOUBLE PRECISION,
    l0_packing_efficiency DOUBLE PRECISION,
    l0_itf_code VARCHAR,
    l0_erp_weight DOUBLE PRECISION,
    l0_erp_volume DOUBLE PRECISION,
    l0_erp_length DOUBLE PRECISION,
    l0_erp_width DOUBLE PRECISION,
    l0_erp_height DOUBLE PRECISION,
    l0_text_tag1 VARCHAR,
    l0_text_tag2 VARCHAR,
    l0_image VARCHAR,
    l0_num_tag1 DOUBLE PRECISION,
    l1_name VARCHAR,
    l1_weight DOUBLE PRECISION,
    l1_volume DOUBLE PRECISION,
    l1_package_type VARCHAR,
    l1_length DOUBLE PRECISION,
    l1_width DOUBLE PRECISION,
    l1_height DOUBLE PRECISION,
    l1_packing_efficiency DOUBLE PRECISION,
    l1_itf_code VARCHAR,
    l1_erp_weight DOUBLE PRECISION,
    l1_erp_volume DOUBLE PRECISION,
    l1_erp_length DOUBLE PRECISION,
    l1_erp_width DOUBLE PRECISION,
    l1_erp_height DOUBLE PRECISION,
    l1_text_tag1 VARCHAR,
    l1_text_tag2 VARCHAR,
    l1_image VARCHAR,
    l1_num_tag1 DOUBLE PRECISION,
    l2_name VARCHAR,
    l2_weight DOUBLE PRECISION,
    l2_volume DOUBLE PRECISION,
    l2_package_type VARCHAR,
    l2_length DOUBLE PRECISION,
    l2_width DOUBLE PRECISION,
    l2_height DOUBLE PRECISION,
    l2_packing_efficiency DOUBLE PRECISION,
    l2_itf_code VARCHAR,
    l2_erp_weight DOUBLE PRECISION,
    l2_erp_volume DOUBLE PRECISION,
    l2_erp_length DOUBLE PRECISION,
    l2_erp_width DOUBLE PRECISION,
    l2_erp_height DOUBLE PRECISION,
    l2_text_tag1 VARCHAR,
    l2_text_tag2 VARCHAR,
    l2_image VARCHAR,
    l2_num_tag1 DOUBLE PRECISION,
    l3_name VARCHAR,
    l3_weight DOUBLE PRECISION,
    l3_volume DOUBLE PRECISION,
    l3_package_type VARCHAR,
    l3_length DOUBLE PRECISION,
    l3_width DOUBLE PRECISION,
    l3_height DOUBLE PRECISION,
    l3_packing_efficiency DOUBLE PRECISION,
    l3_itf_code VARCHAR,
    l3_erp_weight DOUBLE PRECISION,
    l3_erp_volume DOUBLE PRECISION,
    l3_erp_length DOUBLE PRECISION,
    l3_erp_width DOUBLE PRECISION,
    l3_erp_height DOUBLE PRECISION,
    l3_text_tag1 VARCHAR,
    l3_text_tag2 VARCHAR,
    l3_image VARCHAR,
    l3_num_tag1 DOUBLE PRECISION,
    active BOOLEAN,
    classifications VARCHAR,
    product_classifications VARCHAR,
    is_deleted BOOLEAN,
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    PRIMARY KEY (id) NOT ENFORCED,
    WATERMARK FOR created_at AS created_at - INTERVAL '5' SECOND
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.encarta.public.skus_master',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'properties.transaction.id.prefix' = 'encarta-skus-master-consolidated',
    'properties.allow.auto.create.topics' = 'true',
    'properties.num.partitions' = '3',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'key.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'key.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'value.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'value.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}'
);
-- =====================================================
-- CONSOLIDATED INSERT STATEMENT WITH CTEs
-- =====================================================
INSERT INTO skus_master WITH uoms_pivot AS (
        -- First, pivot the UOM data to reduce processing overhead
        SELECT sku_id,
            hierarchy,
            units,
            name,
            weight,
            volume,
            package_type,
            length,
            width,
            height,
            packing_efficiency,
            itf_code,
            erp_weight,
            erp_volume,
            erp_length,
            erp_width,
            erp_height,
            text_tag1,
            text_tag2,
            image,
            num_tag1,
            created_at,
            updated_at
        FROM uoms
        WHERE active = true
            AND COALESCE(is_deleted, false) = false
    ),
    uoms_agg AS (
        -- Optimized aggregation with reduced CASE statement overhead
        SELECT u.sku_id,
            -- L0 hierarchy aggregations
            MAX(
                CASE
                    WHEN u.hierarchy = 'L0' THEN u.units
                END
            ) AS l0_units,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L0' THEN u.name
                END
            ) AS l0_name,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L0' THEN u.weight
                END
            ) AS l0_weight,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L0' THEN u.volume
                END
            ) AS l0_volume,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L0' THEN u.package_type
                END
            ) AS l0_package_type,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L0' THEN u.length
                END
            ) AS l0_length,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L0' THEN u.width
                END
            ) AS l0_width,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L0' THEN u.height
                END
            ) AS l0_height,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L0' THEN u.packing_efficiency
                END
            ) AS l0_packing_efficiency,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L0' THEN u.itf_code
                END
            ) AS l0_itf_code,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L0' THEN u.erp_weight
                END
            ) AS l0_erp_weight,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L0' THEN u.erp_volume
                END
            ) AS l0_erp_volume,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L0' THEN u.erp_length
                END
            ) AS l0_erp_length,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L0' THEN u.erp_width
                END
            ) AS l0_erp_width,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L0' THEN u.erp_height
                END
            ) AS l0_erp_height,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L0' THEN u.text_tag1
                END
            ) AS l0_text_tag1,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L0' THEN u.text_tag2
                END
            ) AS l0_text_tag2,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L0' THEN u.image
                END
            ) AS l0_image,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L0' THEN u.num_tag1
                END
            ) AS l0_num_tag1,
            -- L1 hierarchy aggregations
            MAX(
                CASE
                    WHEN u.hierarchy = 'L1' THEN u.units
                END
            ) AS l1_units,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L1' THEN u.name
                END
            ) AS l1_name,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L1' THEN u.weight
                END
            ) AS l1_weight,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L1' THEN u.volume
                END
            ) AS l1_volume,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L1' THEN u.package_type
                END
            ) AS l1_package_type,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L1' THEN u.length
                END
            ) AS l1_length,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L1' THEN u.width
                END
            ) AS l1_width,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L1' THEN u.height
                END
            ) AS l1_height,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L1' THEN u.packing_efficiency
                END
            ) AS l1_packing_efficiency,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L1' THEN u.itf_code
                END
            ) AS l1_itf_code,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L1' THEN u.erp_weight
                END
            ) AS l1_erp_weight,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L1' THEN u.erp_volume
                END
            ) AS l1_erp_volume,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L1' THEN u.erp_length
                END
            ) AS l1_erp_length,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L1' THEN u.erp_width
                END
            ) AS l1_erp_width,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L1' THEN u.erp_height
                END
            ) AS l1_erp_height,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L1' THEN u.text_tag1
                END
            ) AS l1_text_tag1,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L1' THEN u.text_tag2
                END
            ) AS l1_text_tag2,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L1' THEN u.image
                END
            ) AS l1_image,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L1' THEN u.num_tag1
                END
            ) AS l1_num_tag1,
            -- L2 hierarchy aggregations
            MAX(
                CASE
                    WHEN u.hierarchy = 'L2' THEN u.units
                END
            ) AS l2_units,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L2' THEN u.name
                END
            ) AS l2_name,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L2' THEN u.weight
                END
            ) AS l2_weight,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L2' THEN u.volume
                END
            ) AS l2_volume,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L2' THEN u.package_type
                END
            ) AS l2_package_type,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L2' THEN u.length
                END
            ) AS l2_length,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L2' THEN u.width
                END
            ) AS l2_width,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L2' THEN u.height
                END
            ) AS l2_height,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L2' THEN u.packing_efficiency
                END
            ) AS l2_packing_efficiency,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L2' THEN u.itf_code
                END
            ) AS l2_itf_code,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L2' THEN u.erp_weight
                END
            ) AS l2_erp_weight,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L2' THEN u.erp_volume
                END
            ) AS l2_erp_volume,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L2' THEN u.erp_length
                END
            ) AS l2_erp_length,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L2' THEN u.erp_width
                END
            ) AS l2_erp_width,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L2' THEN u.erp_height
                END
            ) AS l2_erp_height,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L2' THEN u.text_tag1
                END
            ) AS l2_text_tag1,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L2' THEN u.text_tag2
                END
            ) AS l2_text_tag2,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L2' THEN u.image
                END
            ) AS l2_image,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L2' THEN u.num_tag1
                END
            ) AS l2_num_tag1,
            -- L3 hierarchy aggregations
            MAX(
                CASE
                    WHEN u.hierarchy = 'L3' THEN u.units
                END
            ) AS l3_units,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L3' THEN u.name
                END
            ) AS l3_name,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L3' THEN u.weight
                END
            ) AS l3_weight,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L3' THEN u.volume
                END
            ) AS l3_volume,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L3' THEN u.package_type
                END
            ) AS l3_package_type,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L3' THEN u.length
                END
            ) AS l3_length,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L3' THEN u.width
                END
            ) AS l3_width,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L3' THEN u.height
                END
            ) AS l3_height,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L3' THEN u.packing_efficiency
                END
            ) AS l3_packing_efficiency,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L3' THEN u.itf_code
                END
            ) AS l3_itf_code,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L3' THEN u.erp_weight
                END
            ) AS l3_erp_weight,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L3' THEN u.erp_volume
                END
            ) AS l3_erp_volume,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L3' THEN u.erp_length
                END
            ) AS l3_erp_length,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L3' THEN u.erp_width
                END
            ) AS l3_erp_width,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L3' THEN u.erp_height
                END
            ) AS l3_erp_height,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L3' THEN u.text_tag1
                END
            ) AS l3_text_tag1,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L3' THEN u.text_tag2
                END
            ) AS l3_text_tag2,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L3' THEN u.image
                END
            ) AS l3_image,
            MAX(
                CASE
                    WHEN u.hierarchy = 'L3' THEN u.num_tag1
                END
            ) AS l3_num_tag1,
            MIN(u.created_at) AS created_at,
            MAX(u.updated_at) AS updated_at
        FROM uoms_pivot u
        GROUP BY u.sku_id
    ),
    sku_classifications_agg AS (
        SELECT sc.sku_id,
            COALESCE(
                CAST(
                    JSON_OBJECTAGG(KEY sc.type VALUE sc.`value`) AS STRING
                ),
                '{}'
            ) AS classifications,
            MIN(sc.created_at) AS created_at,
            MAX(sc.updated_at) AS updated_at
        FROM (
                SELECT sku_id,
                    type,
                    `value`,
                    created_at,
                    updated_at
                FROM classifications
                WHERE COALESCE(is_deleted, false) = false
            ) sc
        GROUP BY sc.sku_id
    ),
    product_classifications_agg AS (
        SELECT pc.product_id,
            COALESCE(
                CAST(
                    JSON_OBJECTAGG(KEY pc.type VALUE pc.`value`) AS STRING
                ),
                '{}'
            ) AS product_classifications,
            MIN(pc.created_at) AS created_at,
            MAX(pc.updated_at) AS updated_at
        FROM (
                SELECT product_id,
                    type,
                    `value`,
                    created_at,
                    updated_at
                FROM t_product_classifications
                WHERE COALESCE(is_deleted, false) = false
            ) pc
        GROUP BY pc.product_id
    )
SELECT s.id,
    s.principal_id,
    s.code,
    s.name,
    s.description,
    s.short_description,
    s.product_id,
    s.ingredients,
    s.shelf_life,
    s.fulfillment_type,
    s.active_from,
    s.active_till,
    s.identifier1,
    s.identifier2,
    s.invoice_life,
    s.avg_l0_per_put,
    s.inventory_type,
    s.tag1,
    s.tag2,
    s.tag3,
    s.tag4,
    s.tag5,
    s.tag6,
    s.tag7,
    s.tag8,
    s.tag9,
    s.tag10,
    s.layers,
    s.cases_per_layer,
    s.handling_unit_type,
    s.batch_date_print_level,
    p.code AS product_code,
    p.name AS product_name,
    p.description AS product_description,
    p.dangerous,
    p.spillable,
    p.fragile,
    p.flammable,
    p.alcohol,
    p.temperature_controlled,
    p.temp_min,
    p.temp_max,
    p.cold_chain,
    p.shelf_life AS product_shelf_life,
    p.invoice_life AS product_invoice_life,
    subcat.id AS sub_category_id,
    subcat.code AS sub_category_code,
    subcat.name AS sub_category_name,
    subcat.description AS sub_category_description,
    cat.id AS category_id,
    cat.code AS category_code,
    cat.name AS category_name,
    cat.description AS category_description,
    cg.id AS category_group_id,
    cg.code AS category_group_code,
    cg.name AS category_group_name,
    cg.description AS category_group_description,
    sb.id AS sub_brand_id,
    sb.code AS sub_brand_code,
    sb.name AS sub_brand_name,
    sb.description AS sub_brand_description,
    b.id AS brand_id,
    b.code AS brand_code,
    b.name AS brand_name,
    b.description AS brand_description,
    uom_agg.l0_units,
    uom_agg.l1_units,
    uom_agg.l2_units,
    uom_agg.l3_units,
    uom_agg.l0_name,
    uom_agg.l0_weight,
    uom_agg.l0_volume,
    uom_agg.l0_package_type,
    uom_agg.l0_length,
    uom_agg.l0_width,
    uom_agg.l0_height,
    uom_agg.l0_packing_efficiency,
    uom_agg.l0_itf_code,
    uom_agg.l0_erp_weight,
    uom_agg.l0_erp_volume,
    uom_agg.l0_erp_length,
    uom_agg.l0_erp_width,
    uom_agg.l0_erp_height,
    uom_agg.l0_text_tag1,
    uom_agg.l0_text_tag2,
    uom_agg.l0_image,
    uom_agg.l0_num_tag1,
    uom_agg.l1_name,
    uom_agg.l1_weight,
    uom_agg.l1_volume,
    uom_agg.l1_package_type,
    uom_agg.l1_length,
    uom_agg.l1_width,
    uom_agg.l1_height,
    uom_agg.l1_packing_efficiency,
    uom_agg.l1_itf_code,
    uom_agg.l1_erp_weight,
    uom_agg.l1_erp_volume,
    uom_agg.l1_erp_length,
    uom_agg.l1_erp_width,
    uom_agg.l1_erp_height,
    uom_agg.l1_text_tag1,
    uom_agg.l1_text_tag2,
    uom_agg.l1_image,
    uom_agg.l1_num_tag1,
    uom_agg.l2_name,
    uom_agg.l2_weight,
    uom_agg.l2_volume,
    uom_agg.l2_package_type,
    uom_agg.l2_length,
    uom_agg.l2_width,
    uom_agg.l2_height,
    uom_agg.l2_packing_efficiency,
    uom_agg.l2_itf_code,
    uom_agg.l2_erp_weight,
    uom_agg.l2_erp_volume,
    uom_agg.l2_erp_length,
    uom_agg.l2_erp_width,
    uom_agg.l2_erp_height,
    uom_agg.l2_text_tag1,
    uom_agg.l2_text_tag2,
    uom_agg.l2_image,
    uom_agg.l2_num_tag1,
    uom_agg.l3_name,
    uom_agg.l3_weight,
    uom_agg.l3_volume,
    uom_agg.l3_package_type,
    uom_agg.l3_length,
    uom_agg.l3_width,
    uom_agg.l3_height,
    uom_agg.l3_packing_efficiency,
    uom_agg.l3_itf_code,
    uom_agg.l3_erp_weight,
    uom_agg.l3_erp_volume,
    uom_agg.l3_erp_length,
    uom_agg.l3_erp_width,
    uom_agg.l3_erp_height,
    uom_agg.l3_text_tag1,
    uom_agg.l3_text_tag2,
    uom_agg.l3_image,
    uom_agg.l3_num_tag1,
    COALESCE(s.active, FALSE) AS active,
    COALESCE(class_agg.classifications, '{}') AS classifications,
    COALESCE(prod_class_agg.product_classifications, '{}') AS product_classifications,
    COALESCE(s.is_deleted, FALSE) AS is_deleted,
    s.created_at,
    GREATEST(
        COALESCE(s.updated_at, TIMESTAMP '1970-01-01 00:00:00'),
        COALESCE(
            uom_agg.updated_at,
            TIMESTAMP '1970-01-01 00:00:00'
        ),
        COALESCE(
            class_agg.updated_at,
            TIMESTAMP '1970-01-01 00:00:00'
        ),
        COALESCE(
            prod_class_agg.updated_at,
            TIMESTAMP '1970-01-01 00:00:00'
        ),
        COALESCE(p.updated_at, TIMESTAMP '1970-01-01 00:00:00'),
        COALESCE(
            subcat.updated_at,
            TIMESTAMP '1970-01-01 00:00:00'
        ),
        COALESCE(cat.updated_at, TIMESTAMP '1970-01-01 00:00:00'),
        COALESCE(cg.updated_at, TIMESTAMP '1970-01-01 00:00:00'),
        COALESCE(sb.updated_at, TIMESTAMP '1970-01-01 00:00:00'),
        COALESCE(b.updated_at, TIMESTAMP '1970-01-01 00:00:00')
    ) AS updated_at
FROM skus s
    LEFT JOIN uoms_agg AS uom_agg ON s.id = uom_agg.sku_id
    LEFT JOIN sku_classifications_agg AS class_agg ON s.id = class_agg.sku_id
    LEFT JOIN product_classifications_agg AS prod_class_agg ON s.product_id = prod_class_agg.product_id
    LEFT JOIN products AS p ON s.product_id = p.id
    LEFT JOIN sub_categories AS subcat ON p.sub_category_id = subcat.id
    LEFT JOIN categories AS cat ON subcat.category_id = cat.id
    LEFT JOIN category_groups AS cg ON cat.category_group_id = cg.id
    LEFT JOIN sub_brands AS sb ON p.sub_brand_id = sb.id
    LEFT JOIN brands AS b ON sb.brand_id = b.id;