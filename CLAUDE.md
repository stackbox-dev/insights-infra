# Development Guidelines

## CRITICAL SECURITY RULES
- **NEVER commit credentials, passwords, or API keys to the repository**
- **NEVER hardcode sensitive information in any file**
- Always use environment variables or Kubernetes secrets for credentials
- When documenting commands, use placeholder variables like `${KAFKA_USERNAME}` instead of actual values

## Architecture Overview
- **Flink**: Produces staging event streams (no enrichment) to `.flink` namespace topics
- **ClickHouse**: Performs all enrichment via materialized views with dimension tables
- **Kafka**: Uses `${KAFKA_ENV}` environment variable for topic prefixes (e.g., `sbx_uat`)
- **Two-Tier Model**: Staging tables consume Flink events, enriched tables populated via MVs
- **Inventory Snapshots**: 2-tier snapshot model with point-in-time views for efficiency

## Critical Rules

### Naming Conventions
- **Files/Folders**: Use kebab-case (`pick-drop-staging.sql`, `wms-inventory/`)
- **SQL Tables**: Use snake_case (`wms_pick_drop_staging`)
- **No `wms_` prefix** in file names (redundant when already in wms directories)
- **File numbering**: Prefix with `01-`, `02-`, etc. for execution order
- **Utility scripts**: Prefix with `XX-` for non-sequential scripts

### ClickHouse Best Practices
1. **No Nullable columns** - Use defaults for better performance (e.g., `String DEFAULT ''`, `Int64 DEFAULT 0`)
2. **Minimal indexes on staging tables** - Only add indexes for JOIN columns used in enrichment MVs
3. **Single-column JOINs** - Use globally unique IDs (`handling_unit.id`, `storage_bin.id`)
4. **Projections** - Only for frequently queried patterns, not staging tables
5. **ReplacingMergeTree with Projections** - Must include `deduplicate_merge_projection_mode = 'drop'` in SETTINGS:
   ```sql
   ENGINE = ReplacingMergeTree(updated_at)
   ORDER BY (principal_id, code)
   SETTINGS index_granularity = 8192,
            deduplicate_merge_projection_mode = 'drop'
   ```
6. **Schema Alignment with Flink** - Always ensure ClickHouse tables have all fields from corresponding Flink sink tables, including individual timestamp fields
7. **Separated MV and Table Definitions** - Keep enriched table definition separate from its MV for cleaner architecture:
   - Define the enriched table structure in its own file (e.g., `workstation-events-enriched.sql`)
   - Define the MV with `TO <table>` clause in a separate file (e.g., `workstation-events-enriched-mv.sql`)
8. **CRITICAL: Materialized View Column Aliases** - When using `TO <table>` in MVs, EVERY column MUST have an explicit alias:
   - ❌ WRONG: `ie.quant_event_id,` 
   - ✅ CORRECT: `ie.quant_event_id AS quant_event_id,`
   - This applies to ALL columns, even if the column name doesn't change
   - Without explicit aliases, ClickHouse cannot map columns correctly and will throw "NOT_FOUND_COLUMN_IN_BLOCK" errors
9. **Override Patterns in Enrichment MVs** - Handle LEFT JOIN defaults properly:
   - String: `if(so.field != '', so.field, sm.field)`
   - Numeric: `if(so.field != 0, so.field, sm.field)`
   - JSON: `JSONExtractRaw(JSONMergePatch(if(sm.field = '', '{}', sm.field), if(so.field = '', '{}', so.field)))` (handle empty strings)
   - SKU code: Always use `sm.code` (never overridden)
   - Add `AND so.active = true` to all LEFT JOIN with encarta_skus_overrides

### Flink SQL Patterns
1. **Use TTL not Interval Joins** for CDC data: `SET 'table.exec.state.ttl' = '43200000';`
2. **NO WATERMARKS by default** - Do not use watermarks for any pipelines (master or staging) unless explicitly instructed
3. **Filter tombstones**: `WHERE updatedAt > TIMESTAMP '1970-01-01 00:00:00'`
4. **Environment variables**: Use `${KAFKA_ENV}`, `${KAFKA_USERNAME}`, `${KAFKA_PASSWORD}`
5. **For pick-drop**: Compute `event_time` as `GREATEST(pick.updatedAt, drop.updatedAt)`
6. **Reserved Keywords in Flink SQL**: Must quote with backticks when used as field names:
   - Common reserved words: `timestamp`, `type`, `rank`, `level`, `position`, `depth`, `usage`
   - In CREATE TABLE: `` `timestamp` TIMESTAMP(3) NOT NULL``
   - In SELECT statements: ``hue.`type` AS event_type`` or ``hue.`timestamp` AS `timestamp` ``
   - This applies to both field definitions and aliases
   - **Note**: This is specific to Flink SQL. ClickHouse SQL has different reserved words and quoting rules

## Directory Structure
```
insights-infra/
├── clickhouse-supertables/
│   ├── encarta/              # SKU master data
│   │   ├── 01-skus-master.sql
│   │   ├── 02-skus-overrides.sql
│   │   └── 03-skus-combined-view.sql
│   ├── wms-commons/          # Dimension tables (workers, handling_units)
│   ├── wms-inventory/        # Inventory events and positions
│   │   ├── 01-inventory-events-staging.sql
│   │   ├── 02-inventory-events-enriched.sql
│   │   ├── 03-inventory-events-enriched-mv.sql
│   │   ├── 04-inventory-snapshot-table.sql
│   │   └── 05-position-at-time-view.sql
│   ├── wms-pick-drop/        # Pick-drop events
│   ├── wms-storage/          # Storage bins and areas
│   └── wms-workstation-events/
├── flink-studio/sql-executor/
│   ├── pipelines/            # Flink SQL pipelines
│   └── .sbx-uat.env          # Environment config
└── kafka-setup/connectors/
```

## Running Pipelines
```bash
# With environment configuration
python flink_sql_executor.py --sql-file pipelines/wms-pick-drop-staging.sql --env-file .sbx-uat.env
```

## Key Components

### Parameterized SKU View
```sql
-- Use in enrichment MVs
LEFT JOIN encarta_skus_combined(node_id = wh_id) sku ON picked_sku_id = sku.sku_id
```

### Two-Tier Enrichment Pattern
1. Flink produces to `${KAFKA_ENV}.wms.flink.<entity>_staging`
2. ClickHouse staging table consumes staging events (minimal processing)
3. Enriched table defined separately from MV (cleaner architecture)
4. Materialized view enriches with JOINs to dimension tables using `TO <table>`
5. All MV columns must have explicit aliases when using `TO <table>`
6. Enriched data feeds downstream aggregations and views

## Testing & Validation
- Run lint/typecheck after changes: `npm run lint`, `npm run typecheck`
- Test complete pipeline flow before committing
- Verify indexes and projections are partitioned correctly
- Use backfill scripts (`XX-backfill-*.sql`) to rebuild enriched tables
- Monitor with `XX-monitoring-queries.sql` for inventory validation

## Accessing Schema Registry
To get Avro schemas from Kafka Schema Registry, use the flink-session-cluster pod (not taskmanager or sql-gateway):
```bash
# Get pod name
kubectl get pods -n flink-studio | grep flink-session-cluster | grep -v taskmanager

# The credentials are mounted as files in the pod
kubectl exec -n flink-studio <pod-name> -- bash -c '
  KAFKA_USERNAME=$(cat /etc/kafka/secrets/username)
  KAFKA_PASSWORD=$(cat /etc/kafka/secrets/password)
  SCHEMA_REGISTRY_URL="https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159"
  
  curl -s -u "${KAFKA_USERNAME}:${KAFKA_PASSWORD}" \
    "${SCHEMA_REGISTRY_URL}/subjects/sbx_uat.encarta.public.skus-value/versions/latest"
' | jq -r '.schema' | jq '.'
```

## Inventory Snapshot Model
- **Two-tier approach**: Base snapshots + recent events
- **Point-in-time queries**: Use `wms_inventory_position_at_time` view
- **Snapshot building**: Run `build-inventory-snapshots.sh` periodically
- **Configurable frequency**: Adjust snapshot intervals based on needs
```