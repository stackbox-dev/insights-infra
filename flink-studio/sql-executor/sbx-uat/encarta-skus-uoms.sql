-- source table
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
-- destination table
CREATE TABLE skus_uoms_agg (
    sku_id VARCHAR NOT NULL,
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
    created_at TIMESTAMP(3) NOT NULL,
    updated_at TIMESTAMP(3) NOT NULL,
    PRIMARY KEY (sku_id) NOT ENFORCED,
    WATERMARK FOR created_at AS created_at - INTERVAL '5' SECOND
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'sbx_uat.encarta.public.skus_uoms_agg',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    'properties.transaction.id.prefix' = 'encarta-skus-uoms-agg',
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