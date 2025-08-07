SET 'pipeline.name' = 'Encarta SKUs Master Aggregation';
-- Create source tables (DDL for Kafka topics)
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
    classifications STRING,
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    -- CDC snapshot field (READ from true source tables, but never forward directly)
    `__source_snapshot` STRING,
    -- Computed is_snapshot field for CDC snapshot detection
    `is_snapshot` AS COALESCE(
        `__source_snapshot` IN (
            'true',
            'first',
            'first_in_data_collection',
            'last_in_data_collection',
            'last'
        ),
        FALSE
    ),
    -- Computed event time from business timestamps
    `event_time` AS COALESCE(
        updated_at,
        created_at,
        TIMESTAMP '1970-01-01 00:00:00'
    ),
    WATERMARK FOR `event_time` AS `event_time` - INTERVAL '5' SECOND,
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
    classifications STRING,
    active BOOLEAN,
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    -- CDC snapshot field (READ from true source tables, but never forward directly)
    `__source_snapshot` STRING,
    -- Computed is_snapshot field for CDC snapshot detection
    `is_snapshot` AS COALESCE(
        `__source_snapshot` IN (
            'true',
            'first',
            'first_in_data_collection',
            'last_in_data_collection',
            'last'
        ),
        FALSE
    ),
    -- Computed event time from business timestamps
    `event_time` AS COALESCE(
        updated_at,
        created_at,
        TIMESTAMP '1970-01-01 00:00:00'
    ),
    WATERMARK FOR `event_time` AS `event_time` - INTERVAL '5' SECOND,
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
    -- CDC snapshot field (READ from true source tables, but never forward directly)
    `__source_snapshot` STRING,
    -- Computed is_snapshot field for CDC snapshot detection
    `is_snapshot` AS COALESCE(
        `__source_snapshot` IN (
            'true',
            'first',
            'first_in_data_collection',
            'last_in_data_collection',
            'last'
        ),
        FALSE
    ),
    -- Computed event time from business timestamps
    `event_time` AS COALESCE(
        updated_at,
        created_at,
        TIMESTAMP '1970-01-01 00:00:00'
    ),
    WATERMARK FOR `event_time` AS `event_time` - INTERVAL '5' SECOND,
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
    -- CDC snapshot field (READ from true source tables, but never forward directly)
    `__source_snapshot` STRING,
    -- Computed is_snapshot field for CDC snapshot detection
    `is_snapshot` AS COALESCE(
        `__source_snapshot` IN (
            'true',
            'first',
            'first_in_data_collection',
            'last_in_data_collection',
            'last'
        ),
        FALSE
    ),
    -- Computed event time from business timestamps
    `event_time` AS COALESCE(
        updated_at,
        created_at,
        TIMESTAMP '1970-01-01 00:00:00'
    ),
    WATERMARK FOR `event_time` AS `event_time` - INTERVAL '5' SECOND,
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
    -- CDC snapshot field (READ from true source tables, but never forward directly)
    `__source_snapshot` STRING,
    -- Computed is_snapshot field for CDC snapshot detection
    `is_snapshot` AS COALESCE(
        `__source_snapshot` IN (
            'true',
            'first',
            'first_in_data_collection',
            'last_in_data_collection',
            'last'
        ),
        FALSE
    ),
    -- Computed event time from business timestamps
    `event_time` AS COALESCE(
        updated_at,
        created_at,
        TIMESTAMP '1970-01-01 00:00:00'
    ),
    WATERMARK FOR `event_time` AS `event_time` - INTERVAL '5' SECOND,
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
    brand_owner_id STRING,
    active BOOLEAN,
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    -- CDC snapshot field (READ from true source tables, but never forward directly)
    `__source_snapshot` STRING,
    -- Computed is_snapshot field for CDC snapshot detection
    `is_snapshot` AS COALESCE(
        `__source_snapshot` IN (
            'true',
            'first',
            'first_in_data_collection',
            'last_in_data_collection',
            'last'
        ),
        FALSE
    ),
    -- Computed event time from business timestamps
    `event_time` AS COALESCE(
        updated_at,
        created_at,
        TIMESTAMP '1970-01-01 00:00:00'
    ),
    WATERMARK FOR `event_time` AS `event_time` - INTERVAL '5' SECOND,
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
    code STRING,
    name STRING,
    description STRING,
    brand_id STRING,
    active BOOLEAN,
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    -- CDC snapshot field (READ from true source tables, but never forward directly)
    `__source_snapshot` STRING,
    -- Computed is_snapshot field for CDC snapshot detection
    `is_snapshot` AS COALESCE(
        `__source_snapshot` IN (
            'true',
            'first',
            'first_in_data_collection',
            'last_in_data_collection',
            'last'
        ),
        FALSE
    ),
    -- Computed event time from business timestamps
    `event_time` AS COALESCE(
        updated_at,
        created_at,
        TIMESTAMP '1970-01-01 00:00:00'
    ),
    WATERMARK FOR `event_time` AS `event_time` - INTERVAL '5' SECOND,
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
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'key.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'key.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'value.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'value.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}'
);
-- skus_uoms_agg source table (already has event_time from its own pipeline)
CREATE TABLE skus_uoms_agg (
    sku_id STRING,
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
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    `is_snapshot` BOOLEAN NOT NULL,
    `event_time` TIMESTAMP(3) NOT NULL,
    WATERMARK FOR `event_time` AS `event_time` - INTERVAL '5' SECOND,
    PRIMARY KEY (sku_id) NOT ENFORCED
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
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'key.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'key.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'value.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'value.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}'
);
-- Create intermediate views to break join chain and enable parallelization
-- Category hierarchy view - pre-joins category chain to reduce join complexity
CREATE VIEW category_hierarchy AS
SELECT subcat.id as sub_category_id,
    cat.code AS category,
    cg.code AS category_group,
    subcat.updated_at AS subcat_updated_at,
    cat.updated_at AS cat_updated_at,
    cg.updated_at AS cg_updated_at,
    -- Combine is_snapshot from all sources using AND logic
    subcat.`is_snapshot`
    AND cat.`is_snapshot`
    AND cg.`is_snapshot` AS `is_snapshot`,
    GREATEST(
        COALESCE(
            subcat.`event_time`,
            TIMESTAMP '1970-01-01 00:00:00'
        ),
        COALESCE(
            cat.`event_time`,
            TIMESTAMP '1970-01-01 00:00:00'
        ),
        COALESCE(cg.`event_time`, TIMESTAMP '1970-01-01 00:00:00')
    ) AS event_time
FROM sub_categories subcat
    INNER JOIN categories cat ON subcat.category_id = cat.id
    INNER JOIN category_groups cg ON cat.category_group_id = cg.id;
-- Brand hierarchy view - pre-joins brand chain to reduce join complexity  
CREATE VIEW brand_hierarchy AS
SELECT sb.id as sub_brand_id,
    sb.code AS sub_brand,
    b.code AS brand,
    sb.updated_at AS sb_updated_at,
    b.updated_at AS b_updated_at,
    -- Combine is_snapshot from all sources using AND logic
    sb.`is_snapshot`
    AND b.`is_snapshot` AS `is_snapshot`,
    GREATEST(
        COALESCE(sb.`event_time`, TIMESTAMP '1970-01-01 00:00:00'),
        COALESCE(b.`event_time`, TIMESTAMP '1970-01-01 00:00:00')
    ) AS event_time
FROM sub_brands sb
    INNER JOIN brands b ON sb.brand_id = b.id;
-- Products enriched view - joins products with pre-computed hierarchies
CREATE VIEW products_enriched AS
SELECT p.id,
    p.principal_id,
    p.code,
    p.name,
    p.description,
    p.sub_category_id,
    p.sub_brand_id,
    p.dangerous,
    p.spillable,
    p.fragile,
    p.flammable,
    p.alcohol,
    p.temperature_controlled,
    p.temp_min,
    p.temp_max,
    p.cold_chain,
    p.shelf_life,
    p.invoice_life,
    p.classifications,
    p.active,
    p.created_at,
    ch.category,
    ch.category_group,
    bh.sub_brand,
    bh.brand,
    -- Combine is_snapshot from all sources using AND logic
    p.`is_snapshot`
    AND ch.`is_snapshot`
    AND bh.`is_snapshot` AS `is_snapshot`,
    GREATEST(
        COALESCE(p.updated_at, TIMESTAMP '1970-01-01 00:00:00'),
        COALESCE(
            ch.subcat_updated_at,
            TIMESTAMP '1970-01-01 00:00:00'
        ),
        COALESCE(
            ch.cat_updated_at,
            TIMESTAMP '1970-01-01 00:00:00'
        ),
        COALESCE(
            ch.cg_updated_at,
            TIMESTAMP '1970-01-01 00:00:00'
        ),
        COALESCE(
            bh.sb_updated_at,
            TIMESTAMP '1970-01-01 00:00:00'
        ),
        COALESCE(bh.b_updated_at, TIMESTAMP '1970-01-01 00:00:00')
    ) AS updated_at,
    GREATEST(
        COALESCE(p.`event_time`, TIMESTAMP '1970-01-01 00:00:00'),
        COALESCE(ch.`event_time`, TIMESTAMP '1970-01-01 00:00:00'),
        COALESCE(bh.`event_time`, TIMESTAMP '1970-01-01 00:00:00')
    ) AS event_time
FROM products p
    INNER JOIN category_hierarchy ch ON p.sub_category_id = ch.sub_category_id
    INNER JOIN brand_hierarchy bh ON p.sub_brand_id = bh.sub_brand_id;
-- Create final summary table structure (destination table)
CREATE TABLE skus_master (
    id STRING NOT NULL,
    principal_id BIGINT NOT NULL,
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
    active BOOLEAN NOT NULL,
    classifications STRING NOT NULL,
    product_classifications STRING NOT NULL,
    `is_snapshot` BOOLEAN NOT NULL,
    created_at TIMESTAMP(3) NOT NULL,
    updated_at TIMESTAMP(3) NOT NULL,
    `event_time` TIMESTAMP(3) NOT NULL,
    WATERMARK FOR `event_time` AS `event_time` - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
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
    'properties.transaction.id.prefix' = 'encarta-skus-master',
    'key.format' = 'avro-confluent',
    'key.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'key.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'key.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'value.format' = 'avro-confluent',
    'value.avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'value.avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'value.avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}'
);
-- Continuously populate the summary table from source tables
-- Optimized INSERT statement using pre-computed hierarchy views
-- Reduces 7-table join chain to just 3 main joins for better parallelization
INSERT INTO skus_master
SELECT s.id,
    -- Primary key from source matches target primary key
    s.principal_id,
    pe.category AS category,
    pe.code AS product,
    pe.id AS product_id,
    pe.category_group AS category_group,
    pe.sub_brand AS sub_brand,
    pe.brand AS brand,
    s.code,
    s.name,
    s.short_description,
    s.description,
    s.fulfillment_type,
    s.avg_l0_per_put,
    s.inventory_type,
    s.shelf_life,
    s.identifier1,
    s.identifier2,
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
    s.handling_unit_type,
    s.cases_per_layer,
    s.layers,
    s.active_from,
    s.active_till,
    COALESCE(uom_agg.l0_units, 0) AS l0_units,
    COALESCE(uom_agg.l1_units, 0) AS l1_units,
    COALESCE(uom_agg.l2_units, 0) AS l2_units,
    COALESCE(uom_agg.l3_units, 0) AS l3_units,
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
    COALESCE(s.classifications, '{}') AS classifications,
    COALESCE(pe.classifications, '{}') AS product_classifications,
    -- Combine is_snapshot from all sources using AND logic
    -- With INNER JOINs, all values are guaranteed to be present
    s.`is_snapshot`
    AND uom_agg.`is_snapshot`
    AND pe.`is_snapshot` AS `is_snapshot`,
    s.created_at,
    GREATEST(
        COALESCE(s.updated_at, TIMESTAMP '1970-01-01 00:00:00'),
        COALESCE(
            uom_agg.updated_at,
            TIMESTAMP '1970-01-01 00:00:00'
        ),
        COALESCE(pe.updated_at, TIMESTAMP '1970-01-01 00:00:00')
    ) AS updated_at,
    GREATEST(
        COALESCE(s.`event_time`, TIMESTAMP '1970-01-01 00:00:00'),
        COALESCE(
            uom_agg.`event_time`,
            TIMESTAMP '1970-01-01 00:00:00'
        ),
        COALESCE(pe.`event_time`, TIMESTAMP '1970-01-01 00:00:00')
    ) AS event_time
FROM skus s
    INNER JOIN skus_uoms_agg AS uom_agg ON s.id = uom_agg.sku_id
    INNER JOIN products_enriched AS pe ON s.product_id = pe.id;