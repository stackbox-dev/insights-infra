# Schema Updates Guide

This guide outlines the complete process for adding new columns to PostgreSQL source tables and propagating them through the entire data pipeline. Schema updates must be carefully coordinated across all layers to ensure data consistency and avoid pipeline failures.

## Pipeline Architecture Overview

The data flows through four main layers:

```
PostgreSQL → Debezium CDC → Apache Flink → ClickHouse
     ↓            ↓             ↓           ↓
Source Tables  Connectors   Pipelines   Tables/MVs
```

**Key Principle**: With BACKWARD compatible Avro schemas, we can apply changes **progressively** - starting with PostgreSQL source tables and updating downstream components as needed. For breaking changes, use the backwards approach.

## Schema Evolution Strategies

### Strategy A: Progressive Update (Recommended)

This approach leverages BACKWARD compatibility to add columns to PostgreSQL source tables first. Best for:
- Adding optional/nullable fields
- Non-breaking schema changes
- Minimal pipeline disruption

**Flow**: PostgreSQL → Debezium (auto-detects) → Avro Schema Registry → Kafka → Flink (ignores unknown) → ClickHouse

### Strategy B: Conservative Update

Traditional backwards approach starting from ClickHouse. Use for:
- Breaking changes or required fields
- Complex data type changes
- When you need full control over each step

**Flow**: ClickHouse → Flink → Debezium → PostgreSQL

---

## Step-by-Step Process - Progressive Update (Strategy A)

### 1. Pre-Planning Phase

Before making any changes:

1. **Identify Impact Scope**
   - Which source tables will be modified?
   - Which Flink pipelines consume these tables?
   - Which ClickHouse tables are affected?
   - Are there any downstream views or aggregations?

2. **Plan Data Types**
   - PostgreSQL source type
   - Avro schema representation (via Debezium)
   - Flink SQL type mapping
   - ClickHouse destination type
   - Default values for new columns

3. **Backward Compatibility**
   - Ensure new columns are nullable in PostgreSQL (initially)
   - Plan default values for ClickHouse (non-nullable preferred)
   - Consider impact on existing queries

### 1. PostgreSQL Source Tables (First)

With BACKWARD compatible Avro schemas, we can safely add nullable columns to PostgreSQL first.

```sql
-- Example: Adding new_field to pd_pick_item
ALTER TABLE pd_pick_item 
ADD COLUMN new_field VARCHAR(255);

-- Set default value if needed
UPDATE pd_pick_item 
SET new_field = 'default_value' 
WHERE new_field IS NULL;
```

**Key Points**:
- Always add columns as **nullable** initially
- Debezium will auto-detect and register new Avro schema version
- BACKWARD compatibility means existing consumers continue working
- Can make columns NOT NULL later after pipeline updates

### 2. ClickHouse Tables Update (Second)

Add new columns to ClickHouse tables with appropriate defaults:

#### 2.1 Staging Tables

Add new columns to staging tables that consume Flink events:

```sql
-- Example: Adding new_field to wms_pick_drop_staging
ALTER TABLE wms_pick_drop_staging 
ADD COLUMN new_field String DEFAULT '' AFTER existing_field;
```

**Naming Convention**: Use snake_case in ClickHouse, matching Flink sink field names.

#### 2.2 Enriched Tables

Add columns to enriched tables:

```sql
-- Example: Adding new_field to wms_pick_drop_enriched
ALTER TABLE wms_pick_drop_enriched 
ADD COLUMN new_field String DEFAULT '' AFTER existing_field;
```

#### 2.3 Materialized Views

Update materialized views to include new columns with **explicit aliases**:

```sql
-- CRITICAL: All columns must have explicit aliases when using TO <table>
CREATE MATERIALIZED VIEW IF NOT EXISTS wms_pick_drop_enriched_mv
TO wms_pick_drop_enriched
AS
SELECT
    -- Existing columns...
    pb.existing_field AS existing_field,
    pb.new_field AS new_field,  -- ✅ Explicit alias required
    -- More columns...
FROM wms_pick_drop_staging pb
-- JOINs and other logic...
```

**CRITICAL**: Without explicit aliases, ClickHouse throws "NOT_FOUND_COLUMN_IN_BLOCK" errors.

#### 2.4 Dimension Tables

For dimension tables (workers, handling_units, etc.):

```sql
-- Example: Adding new_field to wms_workers
ALTER TABLE wms_workers 
ADD COLUMN new_field String DEFAULT '' AFTER existing_field;

-- Consider adding indexes for frequently queried new columns
ALTER TABLE wms_workers 
ADD INDEX idx_new_field new_field TYPE bloom_filter(0.01) GRANULARITY 1;
```

### 3. Materialized Views Recreation (Third)

**CRITICAL**: ClickHouse materialized views cannot be altered and must be recreated when adding columns.

#### Step 1: Pause Data Flow

```bash
# Pause the Debezium connector to stop new CDC events
curl -X PUT ${CONNECT_REST_URL}/connectors/${WMS_CONNECTOR_NAME}/pause

# Check connector status
curl -s ${CONNECT_REST_URL}/connectors/${WMS_CONNECTOR_NAME}/status | jq '.connector.state'
```

#### Step 2: Update Table Schemas

```sql
-- Add columns to staging table
ALTER TABLE wms_pick_drop_staging 
ADD COLUMN new_field String DEFAULT '' AFTER existing_field;

-- Add columns to enriched table
ALTER TABLE wms_pick_drop_enriched 
ADD COLUMN new_field String DEFAULT '' AFTER existing_field;
```

#### Step 3: Recreate Materialized View

```sql
-- Drop existing MV
DROP VIEW IF EXISTS wms_pick_drop_enriched_mv;

-- Recreate with new columns (ALL columns need explicit aliases)
CREATE MATERIALIZED VIEW wms_pick_drop_enriched_mv
TO wms_pick_drop_enriched
AS
SELECT
    -- Existing columns...
    pb.existing_field AS existing_field,
    pb.new_field AS new_field,  -- ✅ Explicit alias required
    -- More columns...
FROM wms_pick_drop_staging pb
-- JOINs and enrichment logic...
```

**CRITICAL**: Without explicit aliases, ClickHouse throws "NOT_FOUND_COLUMN_IN_BLOCK" errors.

#### Step 4: Resume Data Flow

```bash
# Resume the Debezium connector
curl -X PUT ${CONNECT_REST_URL}/connectors/${WMS_CONNECTOR_NAME}/resume

# Monitor connector status
watch -n 5 'curl -s ${CONNECT_REST_URL}/connectors/${WMS_CONNECTOR_NAME}/status | jq .'
```

#### Step 5: Verify Data Flow

```sql
-- Check that new data is arriving with new columns
SELECT new_field, COUNT(*) 
FROM wms_pick_drop_staging 
WHERE toDate(event_time) = today() 
GROUP BY new_field
ORDER BY COUNT(*) DESC;
```

### 4. Flink SQL Pipelines Update (Optional)

Update Flink SQL pipelines when convenient - they will continue working during the transition:

#### 3.1 Source Table Definitions

Add new columns to Kafka source tables:

```sql
-- Example: Adding new_field to pick_items_raw
CREATE TABLE pick_items_raw (
    -- Existing fields...
    existing_field STRING,
    new_field STRING,  -- Add new field
    -- More fields...
) WITH (
    'connector' = 'kafka',
    'topic' = '${KAFKA_ENV}.wms.public.pd_pick_item',
    -- Connection properties...
);
```

**Reserved Keywords**: Quote with backticks if new field is a reserved word:
```sql
`timestamp` TIMESTAMP(3) NOT NULL,  -- Reserved keyword
```

#### 3.2 Sink Table Definitions

Add new columns to sink tables (staging events):

```sql
-- Example: Adding new_field to pick_drop_staging_unified
CREATE TABLE pick_drop_staging_unified (
    -- Existing fields...
    existing_field STRING,
    new_field STRING,  -- Add new field
    -- More fields...
) WITH (
    'connector' = 'kafka',
    'topic' = '${KAFKA_ENV}.wms.flink.pick_drop_staging',
    -- Upsert-Kafka configuration...
);
```

#### 3.3 SELECT Statements

Update SELECT statements to include new fields:

```sql
-- Example: Including new_field in the pipeline logic
INSERT INTO pick_drop_staging_unified
SELECT
    -- Existing fields...
    p.existing_field,
    p.new_field,  -- Add new field
    -- More fields...
FROM pick_items_raw p
-- JOINs and logic...
```

---

## Step-by-Step Process - Conservative Update (Strategy B)

For breaking changes or when you need full control, use the traditional backwards approach:

### 1. ClickHouse Tables Update (First)

Update ClickHouse tables **before** updating upstream components to prevent schema mismatch errors.

[Previous ClickHouse section content remains here]

### 2. Flink SQL Pipelines Update (Second)

[Previous Flink section content remains here]

### 3. Debezium Connector Update (Third)

Debezium automatically detects new columns, but you may need to:

#### 4.1 Check Table Inclusion

Ensure the modified table is included in the connector's `table.include.list`:

```bash
# In wms-debezium-postgres.sh
TABLE_LIST=$(cat <<EOF
public.pd_pick_item,  # ← Ensure this table is included
public.pd_drop_item,
-- Other tables...
EOF
)
```

#### 4.2 Schema Evolution Settings

Verify schema evolution settings in the connector:

```json
{
  "key.converter.auto.register.schemas": "true",
  "value.converter.auto.register.schemas": "true", 
  "key.converter.schema.compatibility": "BACKWARD",
  "value.converter.schema.compatibility": "BACKWARD"
}
```

#### 4.3 Trigger Schema Refresh (if needed)

If Debezium doesn't pick up changes automatically:

```bash
# Restart the connector to refresh schema
curl -X POST ${CONNECT_REST_URL}/connectors/${WMS_CONNECTOR_NAME}/restart
```

### 4. PostgreSQL Source Tables (Last)

Finally, add the new column to the PostgreSQL source table:

```sql
-- Example: Adding new_field to pd_pick_item
ALTER TABLE pd_pick_item 
ADD COLUMN new_field VARCHAR(255);

-- Set default value if needed
UPDATE pd_pick_item 
SET new_field = 'default_value' 
WHERE new_field IS NULL;

-- Make NOT NULL if desired (after setting defaults)
ALTER TABLE pd_pick_item 
ALTER COLUMN new_field SET NOT NULL;
```

#### 5.1 Publications Update

Ensure the table is included in the Debezium publication:

```sql
-- Check current publication
SELECT * FROM pg_publication_tables WHERE pubname = 'wms_publication';

-- Add table to publication if missing
ALTER PUBLICATION wms_publication ADD TABLE pd_pick_item;
```

## Data Type Mappings

### PostgreSQL → Avro → Flink → ClickHouse

| PostgreSQL | Avro | Flink SQL | ClickHouse |
|------------|------|-----------|------------|
| `VARCHAR(n)`, `TEXT` | `string` | `STRING` | `String DEFAULT ''` |
| `INTEGER` | `int` | `INT` | `Int32 DEFAULT 0` |
| `BIGINT` | `long` | `BIGINT` | `Int64 DEFAULT 0` |
| `BOOLEAN` | `boolean` | `BOOLEAN` | `Bool DEFAULT false` |
| `TIMESTAMP` | `long` (μs) | `TIMESTAMP(3)` | `DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)` |
| `DECIMAL(p,s)` | `bytes` | `DECIMAL(p,s)` | `Decimal(p,s) DEFAULT 0` |
| `JSONB` | `string` | `STRING` | `String DEFAULT '{}'` |

**ClickHouse Best Practice**: Always use DEFAULT values instead of NULL for better performance.

## Column Ordering

### Staging Tables
Add new columns **after** existing columns to maintain compatibility:

```sql
-- ✅ Good: Add at end or after related fields
ALTER TABLE wms_pick_drop_staging 
ADD COLUMN new_pick_field String DEFAULT '' AFTER pick_item_updated_at;

-- ❌ Avoid: Adding at the beginning
ALTER TABLE wms_pick_drop_staging 
ADD COLUMN new_field String DEFAULT '' FIRST;
```

### Enriched Tables
Group related fields together:

```sql
-- ✅ Good: Group with related enrichment data
ALTER TABLE wms_pick_drop_enriched 
ADD COLUMN sku_category String DEFAULT '' AFTER sku_code;
```

## Testing and Validation

### 1. Schema Compatibility Testing

```bash
# Test Flink pipeline with new schema
python flink_sql_executor.py --sql-file pipelines/wms-pick-drop-staging-unified.sql --env-file .sbx-uat.env --dry-run

# Check ClickHouse table structure
clickhouse-client --query "DESCRIBE wms_pick_drop_staging"
```

### 2. Data Flow Validation

```sql
-- Verify new column appears in staging data
SELECT new_field, COUNT(*) 
FROM wms_pick_drop_staging 
WHERE toDate(event_time) = today() 
GROUP BY new_field;

-- Verify enrichment includes new column
SELECT new_field, COUNT(*) 
FROM wms_pick_drop_enriched 
WHERE toDate(event_time) = today() 
GROUP BY new_field;
```

### 3. Pipeline Health Monitoring

```bash
# Check Flink job status
curl -s "${FLINK_REST_URL}/jobs" | jq '.'

# Check Debezium connector status
curl -s "${CONNECT_REST_URL}/connectors/${WMS_CONNECTOR_NAME}/status" | jq '.'
```

## Connector Management

### Pausing and Resuming Connectors

```bash
# List all connectors
curl -s ${CONNECT_REST_URL}/connectors | jq .

# Get connector status
curl -s ${CONNECT_REST_URL}/connectors/${WMS_CONNECTOR_NAME}/status | jq .

# Pause connector (stops CDC events)
curl -X PUT ${CONNECT_REST_URL}/connectors/${WMS_CONNECTOR_NAME}/pause

# Resume connector (continues from last position)
curl -X PUT ${CONNECT_REST_URL}/connectors/${WMS_CONNECTOR_NAME}/resume

# Restart connector (if needed)
curl -X POST ${CONNECT_REST_URL}/connectors/${WMS_CONNECTOR_NAME}/restart
```

### Monitoring During Schema Updates

```bash
# Monitor connector status during update
watch -n 5 'curl -s ${CONNECT_REST_URL}/connectors/${WMS_CONNECTOR_NAME}/status | jq "{name: .name, state: .connector.state, tasks: [.tasks[] | {id: .id, state: .state}]}"'

# Check replication slot position (PostgreSQL)
SELECT slot_name, confirmed_flush_lsn FROM pg_replication_slots WHERE slot_name = '${WMS_SLOT_NAME}';

# Monitor schema registry versions
curl -s -u "${KAFKA_USERNAME}:${KAFKA_PASSWORD}" \
  "${SCHEMA_REGISTRY_URL}/subjects/${WMS_TOPIC_PREFIX}.public.pd_pick_item-value/versions" | jq .
```

## Avro Schema Evolution

### Understanding BACKWARD Compatibility

With `"value.converter.schema.compatibility": "BACKWARD"` in Debezium configuration:

- **New schema can read old data** - consumers with new schema version can process old messages
- **Optional fields only** - new fields must be nullable/optional
- **Automatic evolution** - Debezium auto-registers new schema versions
- **Graceful degradation** - Flink ignores unknown fields, ClickHouse uses DEFAULTs

### Schema Evolution Flow

```
PostgreSQL (add nullable column)
    ↓
Debezium (detects change, registers Avro schema v2)
    ↓  
Kafka (messages with new schema, BACKWARD compatible)
    ↓
Flink (processes both old and new messages)
    ↓
ClickHouse (uses DEFAULT for missing fields)
```

### Checking Schema Versions

```bash
# Get latest schema version
curl -s -u "${KAFKA_USERNAME}:${KAFKA_PASSWORD}" \
  "${SCHEMA_REGISTRY_URL}/subjects/${TOPIC}-value/versions/latest" | jq .

# Check compatibility settings
curl -s -u "${KAFKA_USERNAME}:${KAFKA_PASSWORD}" \
  "${SCHEMA_REGISTRY_URL}/config/${TOPIC}-value" | jq .

# List all schema versions
curl -s -u "${KAFKA_USERNAME}:${KAFKA_PASSWORD}" \
  "${SCHEMA_REGISTRY_URL}/subjects/${TOPIC}-value/versions" | jq .
```

## Backfill After Schema Changes

If you need to rebuild enriched tables after schema changes:

```sql
-- Use backfill scripts to rebuild enriched data
-- Example: XX-backfill-pick-drop-enriched.sql

-- Check data consistency
SELECT 
    'Staging' as table_name,
    COUNT(*) as total_rows,
    COUNT(new_field) as rows_with_new_field
FROM wms_pick_drop_staging
UNION ALL
SELECT 
    'Enriched' as table_name,
    COUNT(*) as total_rows,
    COUNT(new_field) as rows_with_new_field
FROM wms_pick_drop_enriched;
```

## Common Pitfalls and Solutions

### 1. Missing Column Aliases in MVs

**Error**: `NOT_FOUND_COLUMN_IN_BLOCK`

**Cause**: Missing explicit aliases in materialized views using `TO <table>`

**Solution**: Add explicit aliases for ALL columns:
```sql
-- ❌ Wrong
pb.new_field,

-- ✅ Correct  
pb.new_field AS new_field,
```

### 2. Reserved Keyword Conflicts

**Error**: Parse errors in Flink SQL

**Cause**: New column name is a reserved keyword

**Solution**: Quote with backticks in Flink:
```sql
-- Flink SQL
`timestamp` TIMESTAMP(3) NOT NULL,

-- ClickHouse (different reserved words)
timestamp DateTime64(3) DEFAULT toDateTime64('1970-01-01 00:00:00', 3)
```

### 3. Schema Registry Evolution Issues

**Error**: Avro deserialization errors

**Cause**: Schema compatibility conflicts

**Solution**: 
- Use BACKWARD compatibility mode
- Ensure new columns are optional in PostgreSQL initially
- Let Debezium auto-register new schema versions

### 4. ClickHouse Type Mismatches

**Error**: `TYPE_MISMATCH` or conversion errors

**Cause**: Incompatible data types between Flink and ClickHouse

**Solution**: Ensure type mapping compatibility (see Data Type Mappings table)

### 5. Flink State Issues

**Error**: Job failures after schema changes

**Cause**: Incompatible checkpoint/savepoint with new schema

**Solution**:
```bash
# Allow non-restored state (use carefully in production)
SET 'execution.savepoint.ignore-unclaimed-state' = 'true';

# Or start fresh (will lose state)
# Cancel job and restart without savepoint
```

## Rollback Procedures

If issues occur after deployment:

### 1. Immediate Rollback

```sql
-- ClickHouse: Drop column if no data dependency
ALTER TABLE wms_pick_drop_staging DROP COLUMN new_field;
ALTER TABLE wms_pick_drop_enriched DROP COLUMN new_field;

-- Recreate MV without new column
DROP VIEW wms_pick_drop_enriched_mv;
CREATE MATERIALIZED VIEW wms_pick_drop_enriched_mv TO wms_pick_drop_enriched AS ...
```

### 2. Flink Pipeline Rollback

```bash
# Stop current job
curl -X PATCH "${FLINK_REST_URL}/jobs/${JOB_ID}" -d '{"mode":"cancel"}'

# Deploy previous version of SQL file
python flink_sql_executor.py --sql-file pipelines/wms-pick-drop-staging-unified.sql.backup --env-file .sbx-uat.env
```

### 3. PostgreSQL Rollback

```sql
-- Remove column from PostgreSQL (careful - data loss!)
ALTER TABLE pd_pick_item DROP COLUMN new_field;

-- Update publication if needed
ALTER PUBLICATION wms_publication DROP TABLE pd_pick_item;
ALTER PUBLICATION wms_publication ADD TABLE pd_pick_item;
```

## Best Practices Summary

### Progressive Updates (Recommended)
1. **Start with PostgreSQL**: Add nullable columns first to leverage BACKWARD compatibility
2. **Let Debezium auto-evolve**: Schema Registry automatically handles new versions
3. **Use connector pause**: Pause Debezium connectors during MV recreation
4. **Update ClickHouse schemas**: Add columns with appropriate DEFAULTs
5. **Recreate MVs**: Drop and recreate with explicit column aliases
6. **Update Flink when convenient**: Pipelines continue working during transition

### Conservative Updates (Breaking Changes)
1. **Update Order**: ClickHouse → Flink → Debezium → PostgreSQL
2. **Test extensively**: Breaking changes require careful coordination
3. **Plan maintenance windows**: More disruptive approach

### Universal Best Practices
1. **Default Values**: Use appropriate defaults in ClickHouse (no NULLs preferred)
2. **Explicit Aliases**: Always use explicit column aliases in materialized views
3. **Reserved Words**: Quote reserved keywords with backticks in Flink SQL
4. **Testing**: Test schema changes in staging environment first
5. **Monitoring**: Monitor connector and pipeline health during updates
6. **Documentation**: Update table schemas and column descriptions
7. **Rollback Plan**: Have backfill scripts and rollback procedures ready

## Environment-Specific Considerations

### Development/Staging
- Test full pipeline with representative data
- Validate schema evolution with multiple records
- Check performance impact of new indexes

### Production
- Plan maintenance windows for ClickHouse table updates
- Consider creating new columns as nullable initially
- Monitor resource usage during pipeline restarts
- Have rollback procedures tested and ready

## References

- [ARCH.md](./ARCH.md) - Architecture overview
- [CLAUDE.md](./CLAUDE.md) - Development guidelines and naming conventions
- `kafka-setup/scripts/` - Debezium connector management scripts
- `flink-studio/sql-executor/pipelines/` - Flink SQL pipeline definitions
- `clickhouse-supertables/` - ClickHouse table and MV definitions