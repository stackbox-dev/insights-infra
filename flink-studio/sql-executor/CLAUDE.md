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
    -- Business timestamp fields (now directly as TIMESTAMP(3) with AllTimestamptzToEpoch transform)
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    -- CDC snapshot field (READ from true source tables, but never forward directly)
    `__source_snapshot` STRING,  -- Only for reading from Debezium sources
    -- Computed event time from business timestamps (handles nulls)
    `event_time` AS COALESCE(
        updated_at,
        created_at,
        TIMESTAMP '1970-01-01 00:00:00'
    ),
    -- Computed is_snapshot field for CDC snapshot detection (true source tables)
    `is_snapshot` AS COALESCE(`__source_snapshot` IN (
        'true',
        'first',
        'first_in_data_collection',
        'last_in_data_collection',
        'last'
    ), FALSE),
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

#### Key Concepts for Source Tables:

**1. Timestamp Handling:**
- PostgreSQL timestamptz fields are converted to `TIMESTAMP(3)` via `AllTimestamptzToEpoch` transform
- Generate `event_time` from business timestamps: `COALESCE(updated_at, created_at, TIMESTAMP '1970-01-01 00:00:00')`
- Ignore `__source_ts_ms` entirely - use business timestamps only

**2. Snapshot Detection:**
- Read `__source_snapshot` from Debezium sources (don't include `__op` or `__source_ts_ms`)
- Compute `is_snapshot` field, never forward raw `__source_snapshot`
- Combine multiple sources with AND logic: `s1.is_snapshot AND s2.is_snapshot`

**3. Essential Rules:**
- Always propagate `event_time` and `is_snapshot` to sink tables (except aggregations)
- Use watermarks on computed `event_time` field
- Check schema registry for exact data types before defining tables

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
    -- Always include these computed fields for downstream processing
    is_snapshot BOOLEAN NOT NULL,
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

**When to filter by event_time:**
- ✅ **Simple pipelines**: Filter out tombstones/deletes with `WHERE event_time > TIMESTAMP '1970-01-01 00:00:00'`
- ❌ **Aggregation pipelines**: Use business logic filters only, not event_time filters

```sql
-- Simple pipeline - filter event_time
INSERT INTO <sink_table>
SELECT
    field1, field2, ...,
    is_snapshot,
    event_time
FROM source_table
WHERE event_time > TIMESTAMP '1970-01-01 00:00:00';  -- Filters out tombstones

-- Aggregation pipeline - NO event_time filter
INSERT INTO <aggregated_sink>
SELECT
    key_field,
    SUM(amount) AS total_amount,
    MAX(event_time) AS event_time
FROM source_table
WHERE is_active = true  -- Business logic only, no event_time filter
GROUP BY key_field;
```

## Common Patterns

### 1. CDC (Change Data Capture) Tables
CDC data processing with proper event time handling.

### 2. Snapshot Detection
For true source tables from Debezium:
```sql
-- Compute is_snapshot from __source_snapshot field
`is_snapshot` AS COALESCE(`__source_snapshot` IN (
    'true',
    'first',
    'first_in_data_collection',
    'last_in_data_collection',
    'last'
), FALSE)
```

When combining multiple source tables:
```sql
-- Use AND logic for multiple sources
s1.is_snapshot AND s2.is_snapshot AS is_snapshot
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

## CDC Field Forwarding Pattern

**Core Pattern:** READ `__source_snapshot` → COMPUTE `is_snapshot` → FORWARD only `is_snapshot`

### For simple pipelines (1:1 transformations):
- Always propagate `is_snapshot` and `event_time`
- Never forward raw `__source_snapshot`
```sql
INSERT INTO sink_table
SELECT 
    field1, field2, ...,
    is_snapshot,
    event_time
FROM source_table
WHERE event_time > TIMESTAMP '1970-01-01 00:00:00';
```

### For pipelines with multiple sources:
- Combine `is_snapshot` using AND: `s1.is_snapshot AND s2.is_snapshot`
- Use GREATEST for event_time
```sql
INSERT INTO sink_table
SELECT 
    s1.field1, s2.field2, ...,
    s1.is_snapshot AND s2.is_snapshot AS is_snapshot,
    GREATEST(s1.event_time, s2.event_time) AS event_time
FROM source_table1 s1
JOIN source_table2 s2 ON s1.id = s2.foreign_id
WHERE s1.event_time > TIMESTAMP '1970-01-01 00:00:00';
```

### For aggregation pipelines:
- Don't forward `is_snapshot` (loses meaning)
- Keep `event_time` using MAX
```sql
INSERT INTO aggregated_sink
SELECT 
    key_field,
    SUM(amount) AS total_amount,
    MAX(event_time) AS event_time
FROM source_table
WHERE active = true  -- Business logic only
GROUP BY key_field;
```

### Data Type Mappings

| Avro/Debezium Type | Flink SQL Type | Notes |
|-------------------|----------------|-------|
| timestamp-millis (logical type) | TIMESTAMP(3) | PostgreSQL timestamptz fields converted by AllTimestamptzToEpoch transform |
| UUID | STRING | Debezium UUIDs are strings |
| Json | STRING | For JSON fields like attrs |

## Common Issues and Solutions

1. **Computed Column Limitations**
   - **IMPORTANT**: Computed columns cannot reference other computed columns in the same CREATE TABLE
   - **Common scenario**: You cannot use a computed `event_time` in another computed field or WATERMARK
   - Example that FAILS:
     ```sql
     CREATE TABLE source (
         created_at TIMESTAMP(3),
         updated_at TIMESTAMP(3),
         `__source_snapshot` STRING,
         -- First computed column
         `event_time` AS COALESCE(updated_at, created_at, TIMESTAMP '1970-01-01 00:00:00'),
         -- FAILS: Cannot reference event_time here
         `is_valid` AS event_time > TIMESTAMP '2020-01-01 00:00:00'
     )
     ```
   - Correct approach - repeat the logic:
     ```sql
     CREATE TABLE source (
         created_at TIMESTAMP(3),
         updated_at TIMESTAMP(3),
         `__source_snapshot` STRING,
         `event_time` AS COALESCE(updated_at, created_at, TIMESTAMP '1970-01-01 00:00:00'),
         -- Repeat the COALESCE logic instead of referencing event_time
         `is_valid` AS COALESCE(updated_at, created_at, TIMESTAMP '1970-01-01 00:00:00') > TIMESTAMP '2020-01-01 00:00:00',
         `is_snapshot` AS COALESCE(`__source_snapshot` IN ('true', 'first', 'first_in_data_collection', 'last_in_data_collection', 'last'), FALSE)
     )
     ```

2. **Schema Mismatch**
   - Verify field names match Kafka schema exactly
   - Check data types compatibility (especially timestamps)
   - Use schema registry to verify exact types
   - Common error: `Found string, expecting union[null, long]` means wrong data type

3. **Avro Deserialization Errors**
   - PostgreSQL timestamptz fields (with AllTimestamptzToEpoch transform) should be TIMESTAMP(3)
   - Always check schema registry for exact types
   - Use business timestamps for event_time, not __source_ts_ms

4. **Join Performance**
   - Use time windows to bound state
   - Create intermediate views
   - Apply join hints

5. **Checkpointing Failures**
   - Increase checkpoint timeout
   - Reduce mini-batch size
   - Check memory configuration

6. **Data Quality**
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