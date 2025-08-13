# Data Pipeline Architecture

## Overview

This repository contains the data pipeline infrastructure for warehouse management system (WMS) and product catalog (Encarta) data processing. The architecture follows a clean separation of concerns with Apache Flink handling raw event processing and ClickHouse managing enrichment and analytics.

## Architecture Principles

1. **Separation of Concerns**: Flink handles streaming ETL, ClickHouse handles enrichment and analytics
2. **Single Source of Truth**: Each system component has a clearly defined responsibility
3. **Performance Optimization**: Indexes, projections, and partitioning for optimal query performance
4. **Maintainability**: Centralized logic, consistent naming conventions, and clear data flow

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
│  • sbx_uat.wms.internal.* (Processed events)                       │
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
│  • wms-pick-drop-basic.sql                                          │
│  • wms-workstation-events-basic.sql                                 │
│  • wms-inventory-events-basic.sql                                   │
│  • encarta-skus-master.sql                                          │
│  • encarta-skus-overrides.sql                                       │
└──────────────────────┬──────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         ClickHouse                                  │
├─────────────────────────────────────────────────────────────────────┤
│  Layer 1: Staging Tables (Basic Events)                             │
│  • wms_pick_drop_basic                                              │
│  • wms_workstation_events_basic                                     │
│  • wms_inventory_basic_raw_events                                   │
│                                                                     │
│  Layer 2: Dimension Tables                                          │
│  • wms_workers, wms_handling_units, wms_storage_bins                │
│  • wms_storage_bin_master, encarta_skus_master                      │
│  • encarta_skus_overrides                                           │
│                                                                     │
│  Layer 3: Enrichment (Materialized Views)                           │
│  • wms_pick_drop_enriched_mv                                        │
│  • wms_workstation_events_enriched_mv                               │
│  • wms_inventory_enriched_raw_events_mv                             │
│                                                                     │
│  Layer 4: Aggregations                                              │
│  • wms_inventory_hourly_position (hourly aggregates)                │
│  • wms_inventory_weekly_snapshot (cumulative snapshots)             │
└─────────────────────────────────────────────────────────────────────┘
```

## Component Details

### Apache Flink (`/flink-studio/sql-executor/`)

**Purpose**: Real-time stream processing and basic ETL

**Key Responsibilities**:
- Process CDC events from Debezium
- Join related event streams (e.g., pick items + drop items + mappings)
- Handle event time and watermarks
- Detect CDC snapshots
- Produce "basic" events without enrichment

**Configuration**:
- State TTL: 12 hours for pick-drop, 1 hour for inventory
- Checkpointing: 10-minute intervals
- Parallelism: 2 (configurable)
- Output format: Upsert-Kafka with Avro

### ClickHouse (`/clickhouse-summary-tables/`)

**Purpose**: Data enrichment, storage, and analytics

**Directory Structure**:
```
clickhouse-summary-tables/
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
│   ├── pick-drop-basic.sql
│   └── pick-drop-enriched-mv.sql
├── wms-workstation-events/ # Workstation event processing
│   ├── workstation-events-basic.sql
│   └── workstation-events-enriched-mv.sql
└── wms-inventory/           # Inventory event processing
    ├── inventory-basic-raw-events.sql
    ├── inventory-enriched-raw-events-mv.sql
    ├── hourly-position-table.sql
    ├── hourly-position-mv.sql
    └── weekly-snapshot-table.sql
```

## Data Enrichment Strategy

### Dimension Tables
All dimension tables are optimized with:
- **Primary Key**: Single column globally unique ID for fast lookups
- **Indexes**: Bloom filters on frequently queried columns
- **Projections**: Alternative sort orders for common access patterns

### Enrichment Pattern
1. **Staging tables** receive raw events from Flink
2. **Materialized views** JOIN with dimension tables for enrichment
3. **JOINs** are optimized using single-column lookups on unique IDs
4. **Exception**: SKU overrides use composite key (sku_id, node_id) for node-specific data

### SKU Data Management
- **Master Data**: Global SKU information (encarta_skus_master)
- **Overrides**: Node/warehouse-specific customizations (encarta_skus_overrides)
- **Combined View**: Parameterized view that merges master and overrides
- **Logic**: Product hierarchy always from master, other fields prioritize overrides

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
- TTL provides predictable state cleanup
- Works better with historical reprocessing

## Monitoring and Operations

### Key Metrics
- **Flink**: Checkpointing duration, backpressure, state size
- **ClickHouse**: Query performance, storage usage, merge operations
- **Kafka**: Lag, throughput, partition distribution

### Maintenance Tasks
- **Partition Management**: Monthly archival of old partitions
- **Projection Materialization**: After schema changes
- **Statistics Update**: Regular OPTIMIZE TABLE operations

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
- Naming conventions
- ClickHouse best practices
- Flink SQL patterns
- Code style requirements