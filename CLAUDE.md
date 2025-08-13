# Development Guidelines

## Architecture Overview
- **Flink**: Produces staging event streams (no enrichment) to `.flink` namespace topics
- **ClickHouse**: Performs all enrichment via materialized views with dimension tables
- **Kafka**: Uses `${KAFKA_ENV}` environment variable for topic prefixes (e.g., `sbx_uat`)

## Critical Rules

### Naming Conventions
- **Files/Folders**: Use kebab-case (`pick-drop-basic.sql`, `wms-inventory/`)
- **SQL Tables**: Use snake_case (`wms_pick_drop_staging`)
- **No `wms_` prefix** in file names (redundant when already in wms directories)

### ClickHouse Best Practices
1. **No Nullable columns** - Use defaults for better performance
2. **Minimal indexes on staging tables** - Only add indexes for JOIN columns used in enrichment MVs
3. **Single-column JOINs** - Use globally unique IDs (`handling_unit.id`, `storage_bin.id`)
4. **Projections** - Only for frequently queried patterns, not staging tables

### Flink SQL Patterns
1. **Use TTL not Interval Joins** for CDC data: `SET 'table.exec.state.ttl' = '43200000';`
2. **Use direct watermarks** on business timestamps (updatedAt, createdAt, etc.)
3. **Filter tombstones**: `WHERE updatedAt > TIMESTAMP '1970-01-01 00:00:00'`
4. **Environment variables**: Use `${KAFKA_ENV}`, `${KAFKA_USERNAME}`, `${KAFKA_PASSWORD}`
5. **For pick-drop**: Compute `event_time` as `GREATEST(pick.updatedAt, drop.updatedAt)`

## Directory Structure
```
insights-infra/
├── clickhouse-summary-tables/
│   ├── encarta/              # SKU master data
│   ├── wms-commons/          # Dimension tables (workers, handling_units)
│   ├── wms-inventory/        # Inventory events and positions
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

### Enrichment Pattern
1. Flink produces to `${KAFKA_ENV}.wms.flink.<entity>_staging`
2. ClickHouse staging table consumes staging events
3. Materialized view enriches with JOINs to dimension tables
4. Enriched data feeds downstream aggregations

## Testing & Validation
- Run lint/typecheck after changes: `npm run lint`, `npm run typecheck`
- Test complete pipeline flow before committing
- Verify indexes and projections are partitioned correctly