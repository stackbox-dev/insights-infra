# ClickHouse Compression Optimization Guide

## Why Add Explicit Compression Codecs?

### ClickHouse's Default Compression

**Yes, ClickHouse compresses data by default**, but with a **generic one-size-fits-all approach**:

- **Default codec**: `LZ4` compression
- **Applied to**: All columns without explicit codecs
- **Compression ratio**: Typically 3-5x (good, but not optimal)
- **Performance**: Fast compression/decompression, low CPU overhead

### Why Explicit Codecs Help

The default LZ4 is **general-purpose** but **not data-aware**. Explicit codecs leverage **data patterns** for much better results:

| Data Type | Default (LZ4) | Optimized Codec | Why It's Better |
|-----------|---------------|-----------------|-----------------|
| **UUIDs/Sequential IDs** | ~3x compression | `ZSTD(3)` = **50-200x** | ZSTD recognizes repeated patterns in UUIDs |
| **Timestamps** | ~3x compression | `Delta, ZSTD(3)` = **10-20x** | Delta stores differences, not full values |
| **JSON/Text** | ~5x compression | `ZSTD(3)` = **20-30x** | ZSTD dictionary compression excels on structured text |
| **Floats (time-series)** | ~3x compression | `Gorilla, ZSTD(3)` = **5-10x** | Gorilla uses XOR encoding for slowly-changing values |
| **Low-cardinality strings** | ~3x compression | `LowCardinality(String)` = **10-50x** | Dictionary encoding for repeated values |

### Real Example from Your Database

**Without explicit codecs (current state):**
```
wms_workstation_events_enriched.session_id:
- 322.45 MB uncompressed
- Default LZ4: ~100 MB (3x compression)
```

**With explicit ZSTD(3) codec:**
```
wms_workstation_events_enriched.session_id:
- 322.45 MB uncompressed
- ZSTD(3): 1.55 MB (208x compression!)
```

**Why the massive difference?**
- UUIDs have repeating patterns (timestamp prefix, version bits, etc.)
- ZSTD builds a dictionary and recognizes these patterns
- LZ4 just does simple byte-level compression without pattern recognition

## Compression Codecs Reference

### 1. `CODEC(ZSTD(3))` - Best for most data
**Use for**: Strings, IDs, text, JSON, general data

**Compression levels**:
- `ZSTD(1)`: Fastest, ~30% better than LZ4
- `ZSTD(3)`: **Recommended** - Good balance of speed/compression
- `ZSTD(5-9)`: Higher compression, slower (rarely needed)

**Example**:
```sql
ALTER TABLE my_table
  MODIFY COLUMN session_id String CODEC(ZSTD(3));
```

### 2. `CODEC(Delta, ZSTD(3))` - Best for sequential/incremental data
**Use for**: Timestamps, sequential IDs, counters, auto-increment values

**How it works**: Stores the *difference* between consecutive values instead of absolute values
- First value: `1704067200000` (full value)
- Next values: `+1000`, `+1000`, `+1000` (tiny deltas!)

**Example**:
```sql
ALTER TABLE my_table
  MODIFY COLUMN event_timestamp DateTime64(3) CODEC(Delta, ZSTD(3));

ALTER TABLE my_table
  MODIFY COLUMN auto_increment_id Int64 CODEC(Delta, ZSTD(3));
```

### 3. `CODEC(Gorilla, ZSTD(3))` - Best for floats
**Use for**: Float64, Decimal fields (prices, weights, measurements)

**How it works**: XOR-based encoding optimized for values that change slowly
- Great for sensor data, prices, coordinates
- Poor for random floats

**Example**:
```sql
ALTER TABLE my_table
  MODIFY COLUMN price Float64 CODEC(Gorilla, ZSTD(3));

ALTER TABLE my_table
  MODIFY COLUMN weight Float64 CODEC(Gorilla, ZSTD(3));
```

### 4. `LowCardinality(String)` - Best for enums/categories
**Use for**: Status codes, categories, enums (values with <1000 unique values)

**How it works**: Dictionary encoding - store each unique value once, reference by ID
- `'PENDING', 'PENDING', 'COMPLETED', 'PENDING'`
- Becomes: `[0, 0, 1, 0]` with dictionary `{0: 'PENDING', 1: 'COMPLETED'}`

**Example**:
```sql
-- For CREATE TABLE
CREATE TABLE my_table (
  status LowCardinality(String)
);

-- For ALTER TABLE (requires full rewrite)
ALTER TABLE my_table
  MODIFY COLUMN status LowCardinality(String);
```

**⚠️ Warning**: Don't use for high-cardinality data (>10K unique values) - it hurts performance!

## Decision Tree for Choosing Codecs

```
Is the column a Float/Decimal?
├─ YES → Use CODEC(Gorilla, ZSTD(3))
└─ NO → Is it a DateTime/Date/Timestamp?
    ├─ YES → Use CODEC(Delta, ZSTD(3))
    └─ NO → Is it a String with <1000 unique values?
        ├─ YES → Use LowCardinality(String)
        └─ NO → Is it an auto-increment/sequential Int?
            ├─ YES → Use CODEC(Delta, ZSTD(3))
            └─ NO → Use CODEC(ZSTD(3))  [Default choice for everything else]
```

## How to Add Compression to Existing Tables

### Step 1: Analyze current compression
```sql
SELECT
    table,
    name,
    formatReadableSize(data_uncompressed_bytes) as uncompressed,
    formatReadableSize(data_compressed_bytes) as compressed,
    round(data_compressed_bytes / data_uncompressed_bytes, 3) as ratio,
    compression_codec
FROM system.columns
WHERE database = currentDatabase()
    AND table = 'your_table_name'
    AND data_uncompressed_bytes > 10 * 1024 * 1024  -- >10MB
ORDER BY data_uncompressed_bytes DESC;
```

### Step 2: Add ALTER statements to table DDL file
Add at the **bottom** of the file (after CREATE TABLE statement):
```sql
-- ============================================================================
-- COMPRESSION OPTIMIZATION
-- ============================================================================
-- JUSTIFICATION: session_id is 322 MB uncompressed -> 1.5 MB with ZSTD (99.5% compression)
-- UUIDs have repeating patterns that ZSTD can exploit
ALTER TABLE wms_workstation_events_enriched
  MODIFY COLUMN session_id String CODEC(ZSTD(3));

-- JUSTIFICATION: event_timestamp is sequential, Delta encoding reduces by 10-20x
ALTER TABLE wms_workstation_events_enriched
  MODIFY COLUMN event_timestamp DateTime64(3) CODEC(Delta, ZSTD(3));
```

### Step 3: Execute the ALTER statements
```bash
# Option 1: Run the entire file (includes CREATE IF NOT EXISTS + ALTERs)
./run-sql.sh --env .samadhan-prod.env --file wms-workstation-events/02-workstation-events-enriched.sql

# Option 2: Extract just the ALTER statements to a temp file
grep -A 1 "^ALTER TABLE" wms-workstation-events/02-workstation-events-enriched.sql > /tmp/compression-alters.sql
./run-sql.sh --env .samadhan-prod.env --file /tmp/compression-alters.sql --force
```

### Step 4: Force rewrite for immediate effect (optional)
```sql
-- ALTER statements are metadata-only - data recompresses on next merge
-- To force immediate rewrite:
OPTIMIZE TABLE wms_workstation_events_enriched FINAL;
```

**⚠️ Warning**: `OPTIMIZE FINAL` rewrites all data immediately:
- Can take 30min - 2 hours for large tables
- Uses significant CPU and disk I/O
- Monitor disk space (ensure 2x table size is free)
- Consider running during off-peak hours

## High-Impact Targets from Analysis

Based on the production database scan, prioritize these tables/columns:

### 1. wms_workstation_events_enriched (12.33 GiB uncompressed)
**Top columns to compress**:
- `hu_attrs`: 1.95 GiB → 63 MB (**96.8% compression!**) - HIGHEST IMPACT
- `session_id`: 322 MB → 1.5 MB (99.5%)
- `task_id`: 322 MB → 5.2 MB (98.4%)
- `user_id`, `bin_id`, `zone_id`, `area_id`: 300+ MB each → <10 MB

**Estimated savings**: 2-3 GiB

### 2. wms_pick_drop_enriched (9.29 GiB uncompressed)
**Similar patterns to workstation events**

**Estimated savings**: 1.5-2 GiB

### 3. wms_pick_drop_staging (6.37 GiB uncompressed)
**Estimated savings**: 1 GiB

### 4. Large fact tables
- `oms_wms_dock_line` (2.39 GiB)
- `wms_ob_chu_line` (2.30 GiB)
- `wms_sbl_demand_packed` (2.27 GiB)

**Estimated savings**: 500 MB - 1 GiB each

## Important Notes

### Performance Impact
✅ **Pros**:
- **Faster queries**: 10-30% improvement from reduced I/O
- **Lower network usage**: Less data transferred
- **Better cache utilization**: More data fits in memory

❌ **Cons**:
- **Slightly slower inserts**: ZSTD(3) is ~10% slower than LZ4 (usually negligible)
- **Slightly higher CPU on decompression**: ~5-10% more CPU (worth it for I/O savings)

### When NOT to use explicit codecs
- **Very small tables** (<100 MB): Overhead not worth it
- **Temporary/staging tables**: Data deleted quickly anyway
- **High insert rate + low read rate**: Compression overhead may hurt inserts

### Monitoring After Changes
```sql
-- Check compression ratios after OPTIMIZE
SELECT
    table,
    formatReadableSize(sum(data_uncompressed_bytes)) as uncompressed,
    formatReadableSize(sum(data_compressed_bytes)) as compressed,
    round(sum(data_compressed_bytes) / sum(data_uncompressed_bytes), 3) as ratio
FROM system.columns
WHERE database = currentDatabase()
    AND table IN ('wms_workstation_events_enriched', 'wms_pick_drop_enriched')
GROUP BY table;
```

## Summary

**Default ClickHouse compression is good, but generic.**

Explicit codecs are **data-aware** and can achieve:
- **10-200x better compression** for specific data types
- **10-30% faster queries** from reduced I/O
- **Significant disk savings** (multi-GB for large tables)

**The key**: Match the codec to your data pattern for maximum benefit.
