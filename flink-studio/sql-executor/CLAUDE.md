# Flink SQL Pipeline Creation Guide

## Overview
This guide helps you create new Flink SQL pipelines in the sql-executor module. Each pipeline consists of a SQL file that defines source tables, transformations, and sink tables for real-time data processing.

## Directory Structure
```
sql-executor/
├── sbx-uat/              # UAT environment SQL files
│   ├── encarta-*.sql     # Encarta (product catalog) pipelines
│   ├── wms-*.sql         # WMS (warehouse) pipelines
│   └── ...
├── production/           # Production environment SQL files (if exists)
└── test/                 # Test SQL files
```

## SQL File Structure

Each SQL file follows this pattern:

### 1. Pipeline Configuration (Required)
```sql
SET 'pipeline.name' = '<Pipeline Name>';
SET 'table.exec.sink.not-null-enforcer' = 'drop';
SET 'parallelism.default' = '2';
```

### 2. Performance Settings (Optional but Recommended)
```sql
-- Memory and optimization settings
SET 'taskmanager.memory.managed.fraction' = '0.8';
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '1s';
SET 'table.exec.mini-batch.size' = '5000';
SET 'execution.checkpointing.interval' = '600000';
SET 'execution.checkpointing.timeout' = '1800000';
SET 'state.backend.incremental' = 'true';
SET 'state.backend.rocksdb.compression.type' = 'LZ4';
```

### 3. Source Tables (DDL)
Define source tables from Kafka topics:

```sql
CREATE TABLE <source_table_name> (
    -- Column definitions matching Kafka schema EXACTLY
    -- IMPORTANT: Check schema registry for exact data types!
    id STRING,
    field1 TYPE,
    field2 TYPE,
    ...
    -- CDC fields (if using Debezium)
    `__source_ts_ms` BIGINT,  -- NOT TIMESTAMP! It's milliseconds since epoch
    -- Computed event time for watermarking (handles nulls)
    `event_time` AS COALESCE(
        TO_TIMESTAMP_LTZ(`__source_ts_ms`, 3),
        TIMESTAMP '1970-01-01 00:00:00'
    ),
    -- Watermark on computed event_time, not raw fields
    WATERMARK FOR `event_time` AS `event_time` - INTERVAL '5' SECOND,
    -- Primary key if using upsert-kafka
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'kafka' | 'upsert-kafka',
    'topic' = '<environment>.<service>.<database>.<table>',
    'properties.bootstrap.servers' = 'sbx-stag-kafka-stackbox.e.aivencloud.com:22167',
    'properties.group.id' = '<consumer-group-name>',
    -- Security settings
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-512',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="${KAFKA_USERNAME}" password="${KAFKA_PASSWORD}";',
    'properties.ssl.truststore.location' = '/etc/kafka/secrets/kafka.truststore.jks',
    'properties.ssl.truststore.password' = '${TRUSTSTORE_PASSWORD}',
    'properties.ssl.endpoint.identification.algorithm' = 'https',
    -- Schema registry
    'format' = 'avro-confluent',
    'avro-confluent.url' = 'https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159',
    'avro-confluent.basic-auth.credentials-source' = 'USER_INFO',
    'avro-confluent.basic-auth.user-info' = '${KAFKA_USERNAME}:${KAFKA_PASSWORD}',
    'properties.auto.offset.reset' = 'earliest'
);
```

#### Important Notes on Data Types:
- **Timestamps from Debezium**: Use STRING for ZonedTimestamp fields (e.g., `createdAt STRING`)
- **CDC Metadata**: `__source_ts_ms` is BIGINT (milliseconds), not TIMESTAMP
- **Watermarking**: Always use computed columns with COALESCE to handle nulls
- **Schema Verification**: ALWAYS check the Avro schema registry before defining tables

### 4. Intermediate Views (Optional)
Create views to simplify complex joins:

```sql
CREATE VIEW <view_name> AS
SELECT 
    -- Transformed/joined fields
FROM table1
    LEFT JOIN table2 ON condition;
```

### 5. Sink Tables (DDL)
Define destination tables:

```sql
CREATE TABLE <sink_table_name> (
    -- Output schema
    field1 TYPE NOT NULL,
    field2 TYPE,
    ...
    -- Event time for downstream processing
    event_time TIMESTAMP(3) NOT NULL,
    -- Watermark for event time
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = '<environment>.<service>.internal.<output_topic>',
    -- Same Kafka connection settings as source
    ...
    -- Sink-specific settings
    'sink.buffer-flush.max-rows' = '2000',
    'sink.buffer-flush.interval' = '5s',
    'sink.parallelism' = '2'
);
```

### 6. Data Processing Logic (INSERT)
```sql
INSERT INTO <sink_table>
SELECT
    -- Transformation logic
    field1,
    COALESCE(field2, default_value) AS field2,
    ...
FROM source_table1 s1
    LEFT JOIN source_table2 s2 ON s1.id = s2.foreign_id
    -- Time-windowed joins for streaming
    AND s2.event_time BETWEEN s1.event_time - INTERVAL '6' HOUR
    AND s1.event_time + INTERVAL '6' HOUR
WHERE s1.is_deleted = false;
```

## Common Patterns

### 1. CDC (Change Data Capture) Tables
CDC data processing with proper event time handling.

### 2. Snapshot Detection
For snapshot data:
```sql
is_snapshot AS __source_snapshot IN ('true', 'first', 'last')
```

### 3. Time-Windowed Joins
For streaming joins with bounded state (use event_time):
```sql
LEFT JOIN table2 t2 ON t1.id = t2.ref_id
    AND t2.event_time BETWEEN t1.event_time - INTERVAL '6' HOUR
    AND t1.event_time + INTERVAL '6' HOUR
```

### 4. Null Handling
```sql
COALESCE(field, 'DEFAULT_VALUE') AS field
```

### 5. Timestamp Management
```sql
GREATEST(
    COALESCE(t1.updated_at, TIMESTAMP '1970-01-01 00:00:00'),
    COALESCE(t2.updated_at, TIMESTAMP '1970-01-01 00:00:00')
) AS updated_at
```

## Environment-Specific Settings

### UAT/Staging
- Kafka Bootstrap: `sbx-stag-kafka-stackbox.e.aivencloud.com:22167`
- Schema Registry: `https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159`
- Topic Prefix: `sbx_uat.`

### Production
- Update Kafka endpoints accordingly
- Topic Prefix: `prod.` or similar
- Increase parallelism settings

## Pipeline Types

### 1. Simple ETL Pipeline
- Single source table
- Basic transformations
- Single sink table

### 2. Enrichment Pipeline
- Multiple source tables
- Complex joins (products, categories, brands)
- Aggregated output

### 3. Real-time Aggregation
- Windowed aggregations
- Group by operations
- Materialized views

### 4. Event Correlation
- Multiple event streams
- Time-based correlation
- Mapping tables

## Best Practices

1. **Naming Conventions**
   - Files: `<service>-<entity>-<operation>.sql`
   - Tables: Use underscores for multi-word names
   - Topics: `<env>.<service>.<visibility>.<entity>`

2. **Performance Optimization**
   - Use `/*+ USE_HASH_JOIN */` hints for large joins
   - Create intermediate views to break complex join chains
   - Set appropriate watermarks for event time processing
   - Configure mini-batch settings for high-throughput scenarios

3. **Error Handling**
   - Use `COALESCE` for nullable fields
   - Set `'table.exec.sink.not-null-enforcer' = 'drop'` to handle nulls
   - Include `is_deleted` checks for CDC data

4. **Security**
   - Never hardcode credentials
   - Use environment variables: `${KAFKA_USERNAME}`, `${KAFKA_PASSWORD}`, `${TRUSTSTORE_PASSWORD}`
   - Maintain SSL/SASL configuration

5. **Testing**
   - Start with small parallelism (2)
   - Test with sample data first
   - Monitor checkpointing metrics
   - Verify sink data completeness

## Creating a New Pipeline

1. **Identify Requirements**
   - Source systems and topics
   - Required transformations
   - Output format and destination

2. **Create SQL File**
   - Place in appropriate environment folder
   - Follow naming convention
   - Include all sections from template

3. **Define Schema**
   - Match source Kafka schema exactly
   - Define appropriate data types
   - Add watermarks for streaming

4. **Implement Logic**
   - Write transformation queries
   - Handle nulls and edge cases
   - Optimize joins with hints

5. **Test Execution**
   ```bash
   python flink_sql_executor.py --sql-file sbx-uat/your-pipeline.sql
   ```

6. **Monitor**
   - Check Flink UI for job status
   - Verify output in Kafka topics
   - Monitor checkpointing and backpressure

## CDC and Watermarking Best Practices

### Handling CDC Fields
1. **__source_ts_ms Field**
   - Always define as `BIGINT` (not TIMESTAMP)
   - Contains milliseconds since epoch from Debezium
   - Convert to timestamp using `TO_TIMESTAMP_LTZ(__source_ts_ms, 3)`

2. **Event Time Computation**
   ```sql
   -- Compute event_time with null handling
   `event_time` AS COALESCE(
       TO_TIMESTAMP_LTZ(`__source_ts_ms`, 3),
       TIMESTAMP '1970-01-01 00:00:00'
   )
   ```

3. **Watermarking Strategy**
   - Use computed `event_time` field, not raw timestamps
   - Filter out epoch timestamps: `WHERE event_time > TIMESTAMP '1970-01-01 00:00:00'`
   - Forward greatest event_time to sink for multi-source joins

4. **Delete Tombstones**
   - Delete events have null values except keys
   - Will be filtered out when checking `event_time > epoch`
   - Pipeline ignores deletes by default

5. **CDC Field Forwarding**
   - ALWAYS forward `__op`, `__source_ts_ms`, and `__source_snapshot` to sink tables
   - These fields are essential for downstream processing and debugging
   - Include them even in simple 1:1 rekey pipelines
   - Example:
     ```sql
     INSERT INTO sink_table
     SELECT 
         -- business fields
         field1, field2, ...,
         -- CDC metadata (always include)
         `__op`,
         `__source_ts_ms`, 
         `__source_snapshot`,
         `event_time`
     FROM source_table
     WHERE `event_time` > TIMESTAMP '1970-01-01 00:00:00';
     ```

### Data Type Mappings

| Avro/Debezium Type | Flink SQL Type | Notes |
|-------------------|----------------|-------|
| ZonedTimestamp | STRING | Don't use TIMESTAMP(3) |
| long (ms since epoch) | BIGINT | For __source_ts_ms |
| UUID | STRING | Debezium UUIDs are strings |
| Json | STRING | For JSON fields like attrs |

## Common Issues and Solutions

1. **Schema Mismatch**
   - Verify field names match Kafka schema exactly
   - Check data types compatibility (especially timestamps)
   - Use schema registry to verify exact types
   - Common error: `Found string, expecting union[null, long]` means wrong data type

2. **Avro Deserialization Errors**
   - ZonedTimestamp fields must be STRING, not TIMESTAMP(3)
   - __source_ts_ms must be BIGINT, not TIMESTAMP(3)
   - Always check schema registry for exact types

2. **Join Performance**
   - Use time windows to bound state
   - Create intermediate views
   - Apply join hints

3. **Checkpointing Failures**
   - Increase checkpoint timeout
   - Reduce mini-batch size
   - Check memory configuration

4. **Data Quality**
   - Handle `is_deleted` flags
   - Filter snapshot data appropriately
   - Validate timestamp fields

## Examples in This Repository

1. **WMS Pick-Drop Pipeline** (`wms-pick-drop-*.sql`)
   - Complex event correlation
   - Multiple source tables
   - Time-windowed joins
   - Enriched output

2. **Encarta SKUs Pipeline** (`encarta-skus-*.sql`)
   - Product catalog aggregation
   - Hierarchical joins (categories, brands)
   - Master data enrichment
   - UOM aggregation

3. **Inventory Snapshot** (`wms-inventory-snapshot.sql`)
   - Point-in-time snapshots
   - State management
   - CDC processing

## Execution Commands

```bash
# Run a specific SQL file
python flink_sql_executor.py --sql-file sbx-uat/pipeline.sql

# With custom configuration
python flink_sql_executor.py --sql-file sbx-uat/pipeline.sql --config custom-config.yaml

# List running jobs
python flink_sql_executor.py --list-jobs

# Cancel a job
python flink_sql_executor.py --cancel-job <job-id>
```

## Environment Variables Required

```bash
export KAFKA_USERNAME="your-username"
export KAFKA_PASSWORD="your-password"
export TRUSTSTORE_PASSWORD="truststore-password"
```

## Kafka Schema Registry Connection

To connect to the Kafka schema registry, execute into a Flink SQL Gateway pod and use curl:

```bash
# Set credentials as environment variables (ask user or fetch from secure storage)
export KAFKA_USERNAME="${KAFKA_USERNAME:-avnadmin}"
export KAFKA_PASSWORD="${KAFKA_PASSWORD}"  # Must be set in environment

# Get the flink-sql-gateway pod name
kubectl get pods -n flink-studio | grep flink-sql-gateway

# Connect to schema registry (replace POD_NAME with actual pod name)
kubectl exec -n flink-studio POD_NAME -- curl -s "https://${KAFKA_USERNAME}:${KAFKA_PASSWORD}@sbx-stag-kafka-stackbox.e.aivencloud.com:22159/subjects"

# List all available subjects
kubectl exec -n flink-studio POD_NAME -- curl -s "https://${KAFKA_USERNAME}:${KAFKA_PASSWORD}@sbx-stag-kafka-stackbox.e.aivencloud.com:22159/subjects"

# Get specific schema version
kubectl exec -n flink-studio POD_NAME -- curl -s "https://${KAFKA_USERNAME}:${KAFKA_PASSWORD}@sbx-stag-kafka-stackbox.e.aivencloud.com:22159/subjects/<SUBJECT_NAME>/versions/latest"
```

**Schema Registry URL:** `https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159`
**Authentication:** Requires `KAFKA_USERNAME` and `KAFKA_PASSWORD` environment variables

## Additional Resources

- Flink SQL Documentation: https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/sql/
- Kafka Connector: https://nightlies.apache.org/flink/flink-docs-stable/docs/connectors/table/kafka/
- Performance Tuning: https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/config/