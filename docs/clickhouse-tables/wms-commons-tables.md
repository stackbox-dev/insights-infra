# WMS Commons Tables Documentation

## Overview
The WMS Commons tables provide essential dimension data for warehouse operations. These tables contain master data for workers, handling units, sessions, tasks, and trips that are used to enrich operational event data across all WMS analytics.

## Table List
- `wms_workers` - Worker master data
- `wms_handling_unit_kinds` - Handling unit type definitions
- `wms_handling_units` - Individual handling units
- `wms_sessions` - Session information
- `wms_tasks` - Task definitions and status
- `wms_trips` - Trip/delivery information
- `wms_trip_relations` - Parent-child trip relationships

---

## Table: `wms_workers`

### Overview
Worker dimension table containing employee information for workforce analytics and operational tracking.

### Engine & Structure
- **Engine**: `ReplacingMergeTree(updatedAt)`
- **Ordering**: `(id)` - Globally unique worker ID
- **No Partitioning**: Dimension table

### Column Reference
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `whId` | Int64 | 0 | Warehouse identifier |
| `id` | String | - | Unique worker identifier |
| `code` | String | '' | Worker code/badge number |
| `name` | String | '' | Worker full name |
| `phone` | String | '' | Contact phone number |
| `attrs` | String | '{}' | Additional attributes (JSON) |
| `images` | String | '[]' | Worker images (JSON array) |
| `active` | Bool | true | Worker active status |
| `supervisor` | Bool | false | Is supervisor role |
| `quantIdentifiers` | String | '{}' | Quantity identifiers (JSON) |
| `mheKindIds` | String | '[]' | MHE kind IDs (JSON array) |
| `eligibleZones` | String | '[]' | Eligible zones (JSON array) |
| `createdAt` | DateTime64(3) | '1970-01-01 00:00:00' | Creation timestamp |
| `updatedAt` | DateTime64(3) | '1970-01-01 00:00:00' | Last update timestamp |

### Sample Query
```sql
-- Active workers by warehouse with supervisor count
SELECT 
    whId,
    COUNT(*) as total_workers,
    COUNT(CASE WHEN supervisor = true THEN 1 END) as supervisors,
    COUNT(CASE WHEN active = true THEN 1 END) as active_workers,
    STRING_AGG(CASE WHEN supervisor = true THEN name END, ', ') as supervisor_names
FROM wms_workers
WHERE active = true
GROUP BY whId
ORDER BY total_workers DESC;
```

---

## Table: `wms_handling_unit_kinds`

### Overview
Handling unit type definitions containing specifications for different container and packaging types.

### Engine & Structure
- **Engine**: `ReplacingMergeTree(updatedAt)`
- **Ordering**: `(id)` - Globally unique HU kind ID
- **No Partitioning**: Dimension table

### Column Reference
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `whId` | Int64 | 0 | Warehouse identifier |
| `id` | String | - | Unique HU kind identifier |
| `code` | String | '' | HU kind code |
| `name` | String | '' | HU kind name |
| `attrs` | String | '{}' | Additional attributes (JSON) |
| `active` | Bool | true | HU kind active status |
| `maxVolume` | Float64 | 1000000 | Maximum volume capacity |
| `maxWeight` | Float64 | 1000000 | Maximum weight capacity |
| `usageType` | String | '' | Usage type classification |
| `abbr` | String | '' | Abbreviation |
| `length` | Float64 | 0 | Length dimension |
| `breadth` | Float64 | 0 | Breadth/width dimension |
| `height` | Float64 | 0 | Height dimension |
| `weight` | Float64 | 0 | Empty weight |
| `createdAt` | DateTime64(3) | '1970-01-01 00:00:00' | Creation timestamp |
| `updatedAt` | DateTime64(3) | '1970-01-01 00:00:00' | Last update timestamp |

### Sample Query
```sql
-- HU kind capacity analysis
SELECT 
    code,
    name,
    usageType,
    ROUND(maxVolume, 2) as max_volume,
    ROUND(maxWeight, 2) as max_weight,
    ROUND(length * breadth * height, 2) as calculated_volume,
    CASE 
        WHEN maxVolume > 0 THEN ROUND((length * breadth * height) / maxVolume * 100, 2)
        ELSE 0
    END as volume_efficiency_pct
FROM wms_handling_unit_kinds
WHERE active = true
  AND maxVolume > 0
ORDER BY maxVolume DESC;
```

---

## Table: `wms_handling_units`

### Overview
Individual handling unit instances with current state, location, and task assignments.

### Engine & Structure
- **Engine**: `ReplacingMergeTree(updatedAt)`
- **Ordering**: `(id)` - Globally unique HU ID
- **No Partitioning**: Dimension table

### Column Reference
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `whId` | Int64 | 0 | Warehouse identifier |
| `id` | String | - | Unique handling unit identifier |
| `code` | String | '' | HU code/barcode |
| `kindId` | String | '' | HU kind identifier |
| `sessionId` | String | '' | Current session ID |
| `taskId` | String | '' | Current task ID |
| `storageId` | String | '' | Current storage location ID |
| `outerHuId` | String | '' | Outer/parent HU ID |
| `state` | String | '' | Current HU state |
| `attrs` | String | '{}' | Additional attributes (JSON) |
| `lockTaskId` | String | '' | Task that has locked this HU |
| `effectiveStorageId` | String | '' | Effective storage location |
| `createdAt` | DateTime64(3) | '1970-01-01 00:00:00' | Creation timestamp |
| `updatedAt` | DateTime64(3) | '1970-01-01 00:00:00' | Last update timestamp |

### Sample Query
```sql
-- HU state distribution with kind information
SELECT 
    huk.code as kind_code,
    huk.name as kind_name,
    hu.state,
    COUNT(*) as hu_count,
    COUNT(CASE WHEN hu.lockTaskId != '' THEN 1 END) as locked_count,
    COUNT(CASE WHEN hu.outerHuId != '' THEN 1 END) as nested_count
FROM wms_handling_units hu
LEFT JOIN wms_handling_unit_kinds huk ON hu.kindId = huk.id
WHERE hu.whId = 123
GROUP BY huk.code, huk.name, hu.state
ORDER BY hu_count DESC;
```

---

## Table: `wms_sessions`

### Overview
Session information for tracking operational workflows and task groupings.

### Engine & Structure
- **Engine**: `ReplacingMergeTree(updatedAt)`
- **Ordering**: `(id)` - Globally unique session ID
- **No Partitioning**: Dimension table

### Column Reference
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `whId` | Int64 | 0 | Warehouse identifier |
| `id` | String | - | Unique session identifier |
| `kind` | String | '' | Session kind/type |
| `code` | String | '' | Session code |
| `attrs` | String | '{}' | Session attributes (JSON) |
| `active` | Bool | false | Session active status |
| `state` | String | '' | Current session state |
| `progress` | String | '{}' | Progress information (JSON) |
| `autoComplete` | Bool | false | Auto-completion enabled |
| `createdAt` | DateTime64(3) | '1970-01-01 00:00:00' | Creation timestamp |
| `updatedAt` | DateTime64(3) | '1970-01-01 00:00:00' | Last update timestamp |

### Sample Query
```sql
-- Session activity analysis
SELECT 
    kind,
    state,
    COUNT(*) as session_count,
    COUNT(CASE WHEN active = true THEN 1 END) as active_sessions,
    COUNT(CASE WHEN autoComplete = true THEN 1 END) as auto_complete_sessions,
    AVG(dateDiff('minute', createdAt, updatedAt)) as avg_duration_minutes
FROM wms_sessions
WHERE whId = 123
GROUP BY kind, state
ORDER BY session_count DESC;
```

---

## Table: `wms_tasks`

### Overview
Task definitions and execution status for all warehouse operations.

### Engine & Structure
- **Engine**: `ReplacingMergeTree(updatedAt)`
- **Ordering**: `(id)` - Globally unique task ID
- **No Partitioning**: Dimension table

### Column Reference
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `whId` | Int64 | 0 | Warehouse identifier |
| `id` | String | - | Unique task identifier |
| `sessionId` | String | '' | Associated session ID |
| `kind` | String | '' | Task kind/type |
| `code` | String | '' | Task code |
| `seq` | Int32 | 0 | Sequence number |
| `exclusive` | Bool | false | Exclusive execution |
| `state` | String | '' | Current task state |
| `attrs` | String | '{}' | Task attributes (JSON) |
| `progress` | String | '{}' | Progress information (JSON) |
| `active` | Bool | false | Task active status |
| `allowForceComplete` | Bool | false | Allow force completion |
| `autoComplete` | Bool | false | Auto-completion enabled |
| `wave` | Int32 | 0 | Wave number |
| `forceCompleteTaskId` | String | '' | Force complete task ID |
| `forceCompleted` | Bool | false | Force completed status |
| `subKind` | String | '' | Task sub-kind |
| `label` | String | '' | Task label |
| `createdAt` | DateTime64(3) | '1970-01-01 00:00:00' | Creation timestamp |
| `updatedAt` | DateTime64(3) | '1970-01-01 00:00:00' | Last update timestamp |

### Sample Query
```sql
-- Task execution analysis by wave
SELECT 
    wave,
    kind,
    state,
    COUNT(*) as task_count,
    COUNT(CASE WHEN active = true THEN 1 END) as active_tasks,
    COUNT(CASE WHEN forceCompleted = true THEN 1 END) as force_completed,
    AVG(dateDiff('minute', createdAt, updatedAt)) as avg_duration_minutes
FROM wms_tasks
WHERE whId = 123
  AND wave > 0
GROUP BY wave, kind, state
ORDER BY wave, task_count DESC;
```

---

## Table: `wms_trips`

### Overview
Trip and delivery information for inbound and outbound logistics operations.

### Engine & Structure
- **Engine**: `ReplacingMergeTree(createdAt)`
- **Ordering**: `(id)` - Globally unique trip ID
- **No Partitioning**: Dimension table

### Column Reference
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `sessionCreatedAt` | DateTime64(3) | '1970-01-01 00:00:00' | Session creation timestamp |
| `whId` | Int64 | 0 | Warehouse identifier |
| `sessionId` | String | '' | Associated session ID |
| `id` | String | - | Unique trip identifier |
| `createdAt` | DateTime64(3) | '1970-01-01 00:00:00' | Trip creation timestamp |
| `bbId` | String | '' | Building block ID |
| `code` | String | '' | Trip code |
| `type` | String | '' | Trip type (INBOUND/OUTBOUND) |
| `priority` | Int32 | 0 | Trip priority |
| `dockdoorId` | String | '' | Assigned dock door ID |
| `dockdoorCode` | String | '' | Assigned dock door code |
| `vehicleId` | String | '' | Vehicle identifier |
| `vehicleNo` | String | '' | Vehicle number/license |
| `vehicleType` | String | '' | Vehicle type |
| `deliveryDate` | Int32 | 0 | Delivery date (days since epoch) |
| `deliveryDateActual` | Date | - | Computed actual delivery date |

### Sample Query
```sql
-- Trip scheduling analysis
SELECT 
    type,
    toDate(toDateTime(deliveryDate * 24 * 3600)) as delivery_date,
    COUNT(*) as trip_count,
    COUNT(DISTINCT dockdoorCode) as unique_dockdoors,
    COUNT(DISTINCT vehicleType) as vehicle_types,
    AVG(priority) as avg_priority
FROM wms_trips
WHERE whId = 123
  AND deliveryDate > 0
GROUP BY type, delivery_date
ORDER BY delivery_date DESC, type;
```

---

## Table: `wms_trip_relations`

### Overview
Parent-child relationships between trips for cross-docking and multi-leg operations.

### Engine & Structure
- **Engine**: `ReplacingMergeTree(createdAt)`
- **Ordering**: `(id)` - Globally unique relation ID
- **No Partitioning**: Dimension table

### Column Reference
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `whId` | Int64 | 0 | Warehouse identifier |
| `id` | String | - | Unique relation identifier |
| `sessionId` | String | '' | Associated session ID |
| `xdock` | String | '' | Cross-dock identifier |
| `parentTripId` | String | '' | Parent trip ID |
| `childTripId` | String | '' | Child trip ID |
| `createdAt` | DateTime64(3) | '1970-01-01 00:00:00' | Creation timestamp |

### Sample Query
```sql
-- Cross-dock relationship analysis
SELECT 
    xdock,
    COUNT(DISTINCT parentTripId) as parent_trips,
    COUNT(DISTINCT childTripId) as child_trips,
    COUNT(*) as total_relations,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT parentTripId), 2) as avg_children_per_parent
FROM wms_trip_relations
WHERE whId = 123
  AND xdock != ''
GROUP BY xdock
ORDER BY total_relations DESC;
```

---

## Best Practices

### Use Appropriate Timestamp Filters
Since these are dimension tables, they generally don't need timestamp filtering unless tracking changes:

```sql
-- ✅ GOOD: Filter by active status instead of time
SELECT * FROM wms_workers WHERE whId = 123 AND active = true;

-- ✅ GOOD: Recent changes analysis
SELECT * FROM wms_tasks 
WHERE updatedAt >= now() - INTERVAL 1 DAY;
```

### Leverage for Enrichment
These tables are designed for enriching event data:

```sql
-- ✅ GOOD: Enrich pick events with worker information
SELECT 
    pe.pick_id,
    pe.worker_id,
    w.name as worker_name,
    w.supervisor,
    pe.quantity
FROM pick_events pe
LEFT JOIN wms_workers w ON pe.worker_id = w.id
WHERE pe.event_time >= '2024-01-01';
```

### JSON Field Handling
Many tables contain JSON fields for flexible attributes:

```sql
-- Extract specific JSON attributes
SELECT 
    code,
    name,
    JSONExtractString(attrs, 'department') as department,
    JSONExtractBool(attrs, 'certified') as is_certified
FROM wms_workers
WHERE JSONExtractString(attrs, 'department') = 'Picking';
```

## Performance Notes
- All tables use globally unique IDs for optimal JOIN performance
- No partitioning required as these are dimension tables
- Bloom filter indexes on key string columns for fast filtering
- ReplacingMergeTree ensures data consistency
- Designed for high-frequency lookups in enrichment operations