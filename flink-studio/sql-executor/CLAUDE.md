# Flink SQL Pipeline Creation Guide

## Overview
This guide helps you create new Flink SQL pipelines in the sql-executor module. Each pipeline consists of a SQL file that defines source tables, transformations, and sink tables for real-time data processing.

## Critical Best Practices for Debezium/CDC Data

1. **Use TTL instead of Interval Joins**: Debezium data has random ordering (based on PK) which breaks watermark progression. Use `SET 'table.exec.state.ttl' = '43200000';` with regular joins.

2. **Snapshot Detection is Metadata Only**: The `is_snapshot` field should ONLY be forwarded to sink tables for downstream consumers. Never use it for filtering or processing logic.

3. **Filter on event_time, not is_snapshot**: Use `WHERE event_time > TIMESTAMP '1970-01-01 00:00:00'` to filter tombstones, not snapshot flags.

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

## Handling Debezium Data with TTL Instead of Interval Joins

### Why TTL Over Interval Joins for Debezium Data

**Problem with Interval Joins:**
- Debezium produces CDC events with random ordering based on the primary key in the topic
- This random ordering disrupts watermark progression, causing severe issues:
  - Watermarks may jump erratically between old and new timestamps
  - State cleanup becomes unpredictable
  - Join windows may close prematurely or stay open too long
  - Historical data processing becomes unreliable

**Solution: Use TTL (Time To Live) with Regular Joins:**
```sql
-- Set state TTL to prevent unbounded state growth
-- State will be kept for 12 hours after last access
SET 'table.exec.state.ttl' = '43200000'; -- 12 hours in milliseconds

-- Use regular LEFT JOIN instead of interval join
LEFT JOIN table2 t2 ON t1.id = t2.ref_id
    -- No time constraints in the join condition
```

**Benefits of TTL Approach:**
1. **Predictable State Management**: State is cleaned up based on access time, not watermarks
2. **Handles Random Ordering**: Works correctly regardless of event ordering in the topic
3. **Better for Historical Processing**: Can process historical snapshots without watermark issues
4. **Simpler Logic**: No complex time window calculations needed

### Implementation Pattern

```sql
-- At the beginning of your SQL file, configure TTL
SET 'table.exec.state.ttl' = '43200000'; -- 12 hours in milliseconds

-- In your join logic, use regular joins without time constraints
INSERT INTO sink_table
SELECT
    /*+ USE_HASH_JOIN */  -- Use hash join hint for performance
    t1.field1,
    t2.field2,
    -- Combine is_snapshot using AND logic
    t1.is_snapshot AND COALESCE(t2.is_snapshot, FALSE) AS is_snapshot,
    -- Use GREATEST for event_time
    GREATEST(t1.event_time, COALESCE(t2.event_time, TIMESTAMP '1970-01-01 00:00:00')) AS event_time
FROM source_table1 t1
    LEFT JOIN source_table2 t2 
        ON t1.id = t2.foreign_id
        -- No time window constraints here
WHERE t1.event_time > TIMESTAMP '1970-01-01 00:00:00';
```

### Join Strategy Summary

**For CDC/Debezium Data:**
- Use regular joins with TTL for state management
- Avoid interval joins due to random ordering issues

**For Enrichment/Lookup Data:**
- Use temporal joins (`FOR SYSTEM_TIME AS OF`)
- Provides point-in-time correct enrichment
- More efficient than other join types for slowly changing dimensions

**Avoid Interval Joins:**
- Interval joins are problematic with Debezium's random ordering
- They cause unpredictable watermark progression
- State cleanup becomes unreliable
- Use TTL-based regular joins or temporal joins instead

## Common Patterns

### 1. CDC (Change Data Capture) Tables
CDC data processing with proper event time handling using TTL for state management.

### 2. Snapshot Detection (Forward-Only Pattern)

**Important**: Snapshot detection (`is_snapshot`) is now used ONLY for forwarding to sink tables. It should NOT be used for filtering, conditional logic, or any other processing decisions.

**Purpose**: The `is_snapshot` field allows downstream consumers to know if data originated from a CDC snapshot, but should not affect processing logic within pipelines.

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
-- This is ONLY for forwarding, not for filtering
s1.is_snapshot AND s2.is_snapshot AS is_snapshot
```

**What NOT to do:**
```sql
-- ❌ WRONG: Don't filter based on is_snapshot
WHERE NOT is_snapshot  -- Don't do this!

-- ❌ WRONG: Don't use is_snapshot in conditional logic
CASE WHEN is_snapshot THEN ... ELSE ... END  -- Don't do this!

-- ❌ WRONG: Don't use is_snapshot to control joins
ON t1.id = t2.id AND NOT t1.is_snapshot  -- Don't do this!
```

**What TO do:**
```sql
-- ✅ CORRECT: Always forward is_snapshot to sink
INSERT INTO sink_table
SELECT 
    field1, field2, ...,
    is_snapshot,  -- Forward as-is for downstream consumers
    event_time
FROM source_table
WHERE event_time > TIMESTAMP '1970-01-01 00:00:00';  -- Filter on event_time only
```

### 3. Temporal Joins for Enrichment
For enriching streaming data with slowly changing dimension tables:
```sql
-- Define a versioned table (dimension/lookup table)
CREATE TABLE products (
    id STRING,
    name STRING,
    category STRING,
    price DECIMAL(10, 2),
    updated_at TIMESTAMP(3),
    event_time AS updated_at,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (...);

-- Use FOR SYSTEM_TIME AS OF for temporal join
SELECT 
    o.order_id,
    o.product_id,
    p.name AS product_name,
    p.category,
    o.quantity,
    o.quantity * p.price AS total_price
FROM orders o
LEFT JOIN products FOR SYSTEM_TIME AS OF o.event_time AS p
    ON o.product_id = p.id;
```

**Benefits of Temporal Joins:**
- Provides point-in-time correct enrichment
- Automatically manages versioned state
- More efficient than interval joins for lookup scenarios
- Perfect for slowly changing dimensions (products, users, locations)

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

**Core Pattern:** READ `__source_snapshot` → COMPUTE `is_snapshot` → FORWARD only `is_snapshot` (without using it for logic)

**Key Principle**: The `is_snapshot` field is metadata for downstream consumers only. It should NEVER affect your pipeline's processing logic.

### For simple pipelines (1:1 transformations):
- Always propagate `is_snapshot` and `event_time`
- Never forward raw `__source_snapshot`
- Never filter or make decisions based on `is_snapshot`
```sql
INSERT INTO sink_table
SELECT 
    field1, field2, ...,
    is_snapshot,  -- Forward as metadata only
    event_time
FROM source_table
WHERE event_time > TIMESTAMP '1970-01-01 00:00:00';  -- Filter on event_time, NOT is_snapshot
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
- Forward `is_snapshot` using appropriate aggregate function:
  - Use `BOOL_AND(is_snapshot)` or `MIN(is_snapshot)` for "all records are snapshots" semantics
  - Use `BOOL_OR(is_snapshot)` or `MAX(is_snapshot)` for "any record is a snapshot" semantics
  - Choose based on business logic requirements
- Keep `event_time` using MAX
```sql
INSERT INTO aggregated_sink
SELECT 
    key_field,
    SUM(amount) AS total_amount,
    BOOL_AND(is_snapshot) AS is_snapshot,  -- All source records must be snapshots
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

### 1. WMS Pick-Drop Pipelines

The pick-drop system consists of three progressive pipelines:

#### **Basic Pipeline** (`wms-pick-drop-basic.sql`)
   - Joins three CDC source tables: `pd_pick_item`, `pd_drop_item`, and `pd_pick_drop_mapping`
   - Uses TTL-based regular joins (12-hour TTL) to handle Debezium's random ordering
   - Produces comprehensive pick-drop data to `pick_drop_basic` topic
   - Includes all fields needed for enrichment pipelines
   - Properly handles `is_snapshot` and `event_time` propagation

#### **Historical Enrichment** (`wms-pick-drop-enriched-historical.sql`)
   - Consumes from `pick_drop_basic` topic
   - Enriches with dimension data (bins, SKUs, workers, sessions, tasks)
   - Optimized for processing historical/snapshot data
   - Uses temporal joins for point-in-time correct enrichment

#### **Real-time Enrichment** (`wms-pick-drop-enriched-realtime.sql`)
   - Consumes from `pick_drop_basic` topic
   - Same enrichment as historical but optimized for real-time
   - Lower latency configuration for live data processing
   - Uses temporal joins for dimension lookups

### 2. WMS Inventory Pipelines

The inventory system consists of three progressive pipelines:

#### **Events Basic Pipeline** (`wms-inventory-events-basic.sql`)
   - Joins `handling_unit_event` with `handling_unit_quant_event` tables
   - Uses TTL-based regular joins (1-hour TTL) for state management
   - Handles events that lack timestamps in quant events
   - Produces joined inventory events to `inventory_events_basic` topic
   - Note: These are event-driven tables (not CDC), so no `is_snapshot` field

#### **Historical Enrichment** (`wms-inventory-enriched-historical.sql`)
   - Consumes from `inventory_events_basic` topic
   - Enriches with dimension data (SKUs, bins, handling units, workers)
   - Optimized for batch processing of historical data
   - Uses temporal joins for enrichment

#### **Real-time Enrichment** (`wms-inventory-enriched-realtime.sql`)
   - Consumes from `inventory_events_basic` topic
   - Same enrichment as historical but for real-time processing
   - Lower latency configuration
   - Uses temporal joins for live enrichment

### 3. **Encarta SKUs Pipeline** (`encarta-skus-*.sql`)
   - Product catalog aggregation
   - Hierarchical joins (categories, brands)
   - Master data enrichment
   - UOM aggregation

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
# Get the flink-sql-gateway pod name
POD_NAME=$(kubectl get pods -n flink-studio | grep flink-sql-gateway | awk '{print $1}')

# The credentials are stored in the pod's filesystem
# Use this method to access the schema registry:
kubectl exec -n flink-studio $POD_NAME -- bash -c 'KAFKA_USERNAME=$(cat /etc/kafka/secrets/username) && KAFKA_PASSWORD=$(cat /etc/kafka/secrets/password) && curl -s "https://${KAFKA_USERNAME}:${KAFKA_PASSWORD}@sbx-stag-kafka-stackbox.e.aivencloud.com:22159/subjects"'

# List all available subjects (topics)
kubectl exec -n flink-studio $POD_NAME -- bash -c 'KAFKA_USERNAME=$(cat /etc/kafka/secrets/username) && KAFKA_PASSWORD=$(cat /etc/kafka/secrets/password) && curl -s "https://${KAFKA_USERNAME}:${KAFKA_PASSWORD}@sbx-stag-kafka-stackbox.e.aivencloud.com:22159/subjects" | jq -r ".[]"'

# Get specific schema version (replace <TOPIC_NAME> with actual topic)
kubectl exec -n flink-studio $POD_NAME -- bash -c 'KAFKA_USERNAME=$(cat /etc/kafka/secrets/username) && KAFKA_PASSWORD=$(cat /etc/kafka/secrets/password) && curl -s "https://${KAFKA_USERNAME}:${KAFKA_PASSWORD}@sbx-stag-kafka-stackbox.e.aivencloud.com:22159/subjects/<TOPIC_NAME>-value/versions/latest"'

# Get schema fields in a readable format
kubectl exec -n flink-studio $POD_NAME -- bash -c 'KAFKA_USERNAME=$(cat /etc/kafka/secrets/username) && KAFKA_PASSWORD=$(cat /etc/kafka/secrets/password) && curl -s "https://${KAFKA_USERNAME}:${KAFKA_PASSWORD}@sbx-stag-kafka-stackbox.e.aivencloud.com:22159/subjects/<TOPIC_NAME>-value/versions/latest" | jq ".schema | fromjson | .fields"'
```

**Schema Registry URL:** `https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159`
**Authentication:** Credentials are stored in `/etc/kafka/secrets/` within the flink-sql-gateway pod

## Additional Resources

- Flink SQL Documentation: https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/sql/
- Kafka Connector: https://nightlies.apache.org/flink/flink-docs-stable/docs/connectors/table/kafka/
- Performance Tuning: https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/config/