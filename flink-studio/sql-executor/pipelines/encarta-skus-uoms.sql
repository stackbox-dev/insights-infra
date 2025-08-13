SET 'pipeline.name' = 'Encarta SKUs UOMs Aggregation';
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
-- source table
CREATE TABLE uoms (
    id STRING NOT NULL,
    principal_id BIGINT NOT NULL,
    sku_id STRING NOT NULL,
    name STRING,
    hierarchy STRING NOT NULL,
    weight DOUBLE,
    volume DOUBLE,
    package_type STRING,
    length DOUBLE,
    width DOUBLE,
    height DOUBLE,
    units INT,
    packing_efficiency DOUBLE,
    active BOOLEAN,
    itf_code STRING,
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    erp_weight DOUBLE,
    erp_volume DOUBLE,
    erp_length DOUBLE,
    erp_width DOUBLE,
    erp_height DOUBLE,
    text_tag1 STRING,
    text_tag2 STRING,
    image STRING,
    num_tag1 DOUBLE,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = '${KAFKA_ENV}.encarta.public.uoms',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'properties.auto.offset.reset' = 'earliest',
    'properties.allow.auto.create.topics' = 'true',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
    'key.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'key.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
    'value.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'value.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}'
);
-- destination table
CREATE TABLE skus_uoms_agg (
    sku_id STRING NOT NULL,
    l0_units INT,
    l1_units INT,
    l2_units INT,
    l3_units INT,
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
    created_at TIMESTAMP(3) NOT NULL,
    updated_at TIMESTAMP(3) NOT NULL,
    PRIMARY KEY (sku_id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = '${KAFKA_ENV}.encarta.flink.skus_uoms_agg',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'sink.transactional-id-prefix' = 'encarta-skus-uoms-agg',
    'properties.allow.auto.create.topics' = 'true',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
    'key.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'key.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = '${SCHEMA_REGISTRY_URL}',
    'value.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'value.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}'
);
-- populate
-- Population script for UOM aggregations table
INSERT INTO skus_uoms_agg
SELECT u.sku_id,
    MAX(
        CASE
            WHEN u.hierarchy = 'L0' THEN u.units
        END
    ) AS l0_units,
    MAX(
        CASE
            WHEN u.hierarchy = 'L1' THEN u.units
        END
    ) AS l1_units,
    MAX(
        CASE
            WHEN u.hierarchy = 'L2' THEN u.units
        END
    ) AS l2_units,
    MAX(
        CASE
            WHEN u.hierarchy = 'L3' THEN u.units
        END
    ) AS l3_units,
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
FROM uoms u
WHERE u.active = true
GROUP BY u.sku_id;