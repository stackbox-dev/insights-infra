# Data Pipeline Architecture

## Overview

This repository contains the data pipeline infrastructure for warehouse management system (WMS) and product catalog (Encarta) data processing. The architecture follows a clean separation of concerns with Apache Flink handling raw event processing and ClickHouse managing enrichment and analytics.

## Architecture Principles

1. **Separation of Concerns**: Flink handles streaming ETL, ClickHouse handles enrichment and analytics
2. **Single Source of Truth**: Each system component has a clearly defined responsibility
3. **Performance Optimization**: Indexes, projections, and partitioning for optimal query performance
4. **Maintainability**: Centralized logic, consistent naming conventions, and clear data flow
5. **Two-Tier Architecture**: Staging tables consume Flink events, enriched tables populated via MVs
6. **Snapshot-Based Recovery**: Inventory snapshots enable efficient point-in-time queries

## Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Source Systems                              │
├─────────────────────────────────────────────────────────────────────┤
│  • WMS PostgreSQL (CDC via Debezium)                                │
│  • Encarta PostgreSQL (CDC via Debezium)                            │
│  • Event Streams                                                    │
└──────────────────────┬──────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        Apache Kafka                                 │
├─────────────────────────────────────────────────────────────────────┤
│  Topics:                                                            │
│  • sbx_uat.wms.public.* (CDC tables)                                │
│  • sbx_uat.encarta.public.* (CDC tables)                           │
│  • sbx_uat.wms.flink.* (Flink staging events)                      │
└──────────────────────┬──────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        Apache Flink                                 │
├─────────────────────────────────────────────────────────────────────┤
│  Responsibilities:                                                  │
│  • CDC event processing                                             │
│  • Event joining (e.g., pick + drop + mapping)                      │
│  • Basic transformations                                            │
│  • Snapshot detection                                               │
│                                                                     │
│  Pipelines:                                                         │
│  • wms-pick-drop-staging.sql                                        │
│  • wms-workstation-events-staging.sql                               │
│  • wms-inventory-events-staging.sql                                 │
│  • encarta-skus-master.sql                                          │
│  • encarta-skus-overrides.sql                                       │
└──────────────────────┬──────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         ClickHouse                                  │
├─────────────────────────────────────────────────────────────────────┤
│  Layer 1: Staging Tables (Flink Events)                             │
│  • wms_pick_drop_staging                                            │
│  • wms_workstation_events_staging                                   │
│  • wms_inventory_events_staging                                     │
│                                                                     │
│  Layer 2: Dimension Tables                                          │
│  • wms_workers, wms_handling_units, wms_storage_bins                │
│  • wms_storage_bin_master, encarta_skus_master                      │
│  • encarta_skus_overrides                                           │
│                                                                     │
│  Layer 3: Enriched Tables & Materialized Views                      │
│  • wms_pick_drop_enriched (table + MV)                              │
│  • wms_workstation_events_enriched (table + MV)                     │
│  • wms_inventory_events_enriched (table + MV)                       │
│                                                                     │
│  Layer 4: Aggregations & Views                                      │
│  • wms_inventory_snapshot (2-tier snapshot model)                   │
│  • wms_inventory_position_at_time (point-in-time view)              │
│  • Various analytics views and aggregations                         │
└─────────────────────────────────────────────────────────────────────┘
```

## Component Details

### Apache Flink (`/flink-studio/sql-executor/`)

**Purpose**: Real-time stream processing and basic ETL

**Key Responsibilities**:
- Process CDC events from Debezium
- Join related event streams (e.g., pick items + drop items + mappings)
- Handle event time computation (e.g., GREATEST for pick-drop)
- Detect CDC snapshots via snapshot field
- Produce "staging" events without enrichment
- Filter tombstones: `updatedAt > TIMESTAMP '1970-01-01 00:00:00'`

**Configuration**:
- State TTL: 12 hours (43200000ms) for pick-drop, 1 hour for inventory
- Checkpointing: 10-minute intervals
- Parallelism: 2 (configurable)
- Output format: Upsert-Kafka with Avro
- NO WATERMARKS by default (unless explicitly required)
- Reserved keywords: Must quote with backticks (e.g., ``timestamp``, ``type``)

### ClickHouse (`/clickhouse-summary-tables/`)

**Purpose**: Data enrichment, storage, and analytics

**Directory Structure**:
```
clickhouse-supertables/
├── encarta/                 # Product catalog dimension tables
│   ├── skus-master.sql
│   ├── skus-overrides.sql
│   └── skus-combined-view.sql
├── wms-commons/             # WMS dimension tables
│   ├── workers.sql
│   ├── handling-units.sql
│   └── ...
├── wms-storage/             # Storage-related dimension tables
│   ├── storage-bins.sql
│   └── storage-bin-master.sql
├── wms-pick-drop/           # Pick-drop event processing
│   ├── 01-pick-drop-staging.sql
│   ├── 02-pick-drop-enriched.sql
│   └── 03-pick-drop-enriched-mv.sql
├── wms-workstation-events/ # Workstation event processing
│   ├── 01-workstation-events-staging.sql
│   ├── 02-workstation-events-enriched.sql
│   └── 03-workstation-events-enriched-mv.sql
└── wms-inventory/           # Inventory event processing
    ├── 01-inventory-events-staging.sql
    ├── 02-inventory-events-enriched.sql
    ├── 03-inventory-events-enriched-mv.sql
    ├── 04-inventory-snapshot-table.sql
    └── 05-position-at-time-view.sql
```

## Data Enrichment Strategy

### Dimension Tables
All dimension tables are optimized with:
- **Primary Key**: Single column globally unique ID for fast lookups
- **Indexes**: Bloom filters on frequently queried columns
- **Projections**: Alternative sort orders for common access patterns

### Two-Tier Enrichment Pattern
1. **Flink produces** staging events to `${KAFKA_ENV}.wms.flink.<entity>_staging` topics
2. **Staging tables** consume Flink events with minimal processing
3. **Enriched tables** are populated by MVs that JOIN staging with dimension tables
4. **Separated definitions**: Enriched table structure separate from MV definition
5. **JOINs** are optimized using single-column lookups on unique IDs
6. **SKU enrichment**: Uses parameterized view `encarta_skus_combined(node_id)`
7. **Column aliases**: All MV columns must have explicit aliases when using `TO <table>`

### SKU Data Management
- **Master Data**: Global SKU information (encarta_skus_master)
- **Overrides**: Node/warehouse-specific customizations (encarta_skus_overrides)
- **Combined View**: Parameterized view that merges master and overrides
- **Override Pattern**: 
  - String: `if(so.field != '', so.field, sm.field)`
  - Numeric: `if(so.field != 0, so.field, sm.field)`
  - JSON: `JSONMergePatch` with empty string handling
  - SKU code: Always use `sm.code` (never overridden)
  - Filter: `AND so.active = true` for all override JOINs

## Performance Optimizations

### Indexes
- **MinMax**: For range queries (wh_id, timestamps)
- **Bloom Filters**: For exact match lookups (IDs, codes)
- **Granularity**: Optimized per column usage pattern

### Projections
- **Primary**: Optimized for most common query pattern
- **Secondary**: Alternative sort orders for specific use cases
- **Partitioned**: Projections are automatically partitioned with data

### Partitioning
- **Monthly**: `PARTITION BY toYYYYMM(timestamp)`
- **Benefits**: Efficient data pruning, parallel processing, easy archival
- **Indexes/Projections**: Automatically partitioned with data

## Naming Conventions

### Files
- **Kebab-case**: All file and folder names (e.g., `pick-drop-basic.sql`)
- **Descriptive**: `<domain>-<entity>-<type>.sql`

### Tables
- **Prefixes**: 
  - `wms_` for warehouse management tables
  - `encarta_` for product catalog tables
- **Suffixes**:
  - `_mv` for materialized views
  - `_basic` for staging tables

### Columns
- **Snake_case**: For all column names
- **Consistent**: Same field names across related tables

## Key Design Decisions

### 1. Flink vs ClickHouse Enrichment
**Decision**: Move all enrichment from Flink to ClickHouse
**Rationale**: 
- Better performance with indexes and projections
- Simpler pipeline management
- Easier to update dimension data without reprocessing streams

### 2. Parameterized Views for SKUs
**Decision**: Use parameterized view for SKU master/override combination
**Rationale**:
- Centralizes override logic
- Simplifies enrichment queries
- Maintains good performance with proper indexes

### 3. No Nullable Columns
**Decision**: Use defaults instead of NULL values
**Rationale**:
- Better ClickHouse performance
- Simpler query logic
- Predictable aggregations

### 4. TTL-based Joins in Flink
**Decision**: Use state TTL instead of interval joins for CDC data
**Rationale**:
- CDC events have random ordering
- TTL provides predictable state cleanup (12h for pick-drop, 1h for inventory)
- Works better with historical reprocessing
- No watermarks by default to avoid event dropping

### 5. Separated Table and MV Definitions
**Decision**: Keep enriched table definitions separate from their materialized views
**Rationale**:
- Cleaner architecture and easier maintenance
- Table schema can be modified independently
- MV uses `TO <table>` clause for better performance
- Explicit column aliases required for proper mapping

### 6. Two-Tier Inventory Snapshot Model
**Decision**: Implement snapshot tables with point-in-time view
**Rationale**:
- Efficient historical queries via snapshots
- Combines snapshot + recent events for current state
- Reduces computation for time-travel queries
- Supports configurable snapshot frequency

## Monitoring and Operations

### Key Metrics
- **Flink**: Checkpointing duration, backpressure, state size
- **ClickHouse**: Query performance, storage usage, merge operations
- **Kafka**: Lag, throughput, partition distribution

### Maintenance Tasks
- **Partition Management**: Monthly archival of old partitions
- **Projection Materialization**: After schema changes
- **Statistics Update**: Regular OPTIMIZE TABLE operations
- **Snapshot Building**: Periodic inventory snapshots via scripts
- **Backfill Operations**: Scripts for rebuilding enriched tables

## Future Considerations

### Potential Optimizations
1. **ClickHouse Dictionaries**: For ultra-fast dimension lookups
2. **Pre-aggregated Views**: For common query patterns
3. **Distributed Tables**: For multi-node ClickHouse deployment

### Scalability Path
1. **Horizontal Scaling**: Add ClickHouse replicas for read scaling
2. **Sharding**: Distribute data across nodes by warehouse ID
3. **Tiered Storage**: Hot/cold data separation

## Development Guidelines

See [`CLAUDE.md`](./CLAUDE.md) for detailed development guidelines including:
- Naming conventions (kebab-case files, snake_case tables)
- ClickHouse best practices (no nullable columns, separated MVs)
- Flink SQL patterns (TTL-based joins, tombstone filtering)
- Security rules (no hardcoded credentials)
- Testing and validation requirements