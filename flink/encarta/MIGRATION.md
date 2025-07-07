# Migration Guide: Existing Pipelines to New Schema

This document outlines the migration strategy for existing Flink SQL pipelines to the new schema that includes both `created_at` and `updated_at` columns.

## 🔄 **Schema Changes Overview**

### **What Changed**
All custom tables now include both timestamp columns:
- `created_at TIMESTAMP_LTZ(3) NOT NULL` - Record creation time
- `updated_at TIMESTAMP_LTZ(3) NOT NULL` - Last modification time

### **Affected Tables**
1. `skus_master` - Main denormalized table (117 fields now)
2. `skus_uoms_agg` - UOM aggregations (80 fields now)
3. `skus_classifications_agg` - SKU classifications (4 fields now)
4. `products_classifications_agg` - Product classifications (4 fields now)

## 📋 **Migration Strategy**

### **Phase 1: Backup and Prepare**
```bash
# 1. Stop all existing streaming jobs
# 2. Backup existing table schemas and data
# 3. Document current pipeline state
```

### **Phase 2: Schema Migration**

#### **Option A: Zero-Downtime Migration (Recommended)**
```sql
-- 1. Create new tables with _v2 suffix
-- 2. Start dual-write to both old and new tables
-- 3. Backfill historical data
-- 4. Switch reads to new tables
-- 5. Stop writes to old tables
-- 6. Drop old tables and rename new ones
```

#### **Option B: Maintenance Window Migration**
```sql
-- 1. Stop all pipelines
-- 2. Alter existing tables to add updated_at column
-- 3. Update all SQL scripts
-- 4. Restart pipelines
```

### **Phase 3: Schema Migration Strategy**

#### **Important Note: ALTER TABLE Limitations**
According to Confluent Cloud for Apache Flink documentation, **physical columns cannot be added, modified, or dropped** using ALTER TABLE. Schema evolution must be handled through Schema Registry.

#### **Option A: Schema Registry Evolution (Recommended)**
```sql
-- 1. Evolve schemas in Schema Registry to include updated_at field
-- 2. Use schema evolution compatibility (FULL_TRANSITIVE recommended)
-- 3. Deploy new table definitions with both timestamps
-- 4. Flink will automatically pick up the new schema
```

#### **Option B: Table Recreation (Zero-Downtime)**
```sql
-- 1. Create new tables with _v2 suffix including both timestamps
-- 2. Start dual-write streaming jobs to both old and new tables
-- 3. Backfill historical data in new tables
-- 4. Switch read operations to new tables
-- 5. Stop writes to old tables
-- 6. Drop old tables and rename new ones
```

#### **Option C: Table Recreation (Maintenance Window)**
```sql
-- 1. Stop all streaming pipelines
-- 2. Drop existing tables
-- 3. Create new tables with updated schema (both timestamps)
-- 4. Update all SQL scripts
-- 5. Restart streaming pipelines
-- 6. Backfill data if needed
```

### **Phase 4: Schema Registry Updates**

#### **For each affected table, update the Avro schema in Schema Registry:**

**skus_master schema evolution:**
```json
{
  "type": "record",
  "name": "skus_master",
  "fields": [
    // ... existing fields ...
    {
      "name": "created_at",
      "type": "long",
      "logicalType": "timestamp-millis"
    },
    {
      "name": "updated_at", 
      "type": "long",
      "logicalType": "timestamp-millis"
    }
  ]
}
```

**Aggregation tables schema evolution:**
```json
{
  "type": "record", 
  "name": "skus_uoms_agg",
  "fields": [
    // ... existing fields ...
    {
      "name": "created_at",
      "type": "long", 
      "logicalType": "timestamp-millis"
    },
    {
      "name": "updated_at",
      "type": "long",
      "logicalType": "timestamp-millis" 
    }
  ]
}
```

### **Phase 5: Table Recreation Commands**

#### **Drop and Recreate Tables (if using Option C)**
```sql
-- Stop all streaming jobs first
-- IMPORTANT: Backup data before dropping tables

-- Drop existing tables
DROP TABLE IF EXISTS `sbx-uat.encarta.public.skus_master`;
DROP TABLE IF EXISTS `sbx-uat.encarta.public.skus_uoms_agg`; 
DROP TABLE IF EXISTS `sbx-uat.encarta.public.skus_classifications_agg`;
DROP TABLE IF EXISTS `sbx-uat.encarta.public.products_classifications_agg`;

-- Create new tables with updated schema (run the new table_*.sql files)
-- These will automatically pick up the evolved schemas from Schema Registry
```

#### **Create V2 Tables (if using Option B)**
```sql
-- Create new tables with _v2 suffix using the new table definitions
-- Example:
CREATE TABLE `sbx-uat.encarta.public.skus_master_v2` (
    -- ... full schema with both created_at and updated_at ...
);

-- Repeat for all aggregation tables
```

### **Phase 6: Update SQL Scripts**

#### **Population Scripts Updates**
All populate scripts now include both timestamp columns:

```sql
-- Example from populate_skus_uoms_agg.sql
SELECT 
    -- ... existing fields ...
    MAX(u.created_at) AS created_at,
    MAX(u.updated_at) AS updated_at
FROM `sbx-uat.encarta.public.uoms` u
-- ... rest of query ...
```

#### **Main Insert Script Updates**
```sql
-- insert_skus_master.sql now includes both columns
SELECT 
    -- ... existing fields ...
    s.created_at,
    s.updated_at
FROM `sbx-uat.encarta.public.skus` s
-- ... rest of query ...
```

### **Phase 7: Validation and Testing**

#### **Data Validation Checklist**
```sql
-- 1. Verify field counts match
SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'skus_master'; -- Should be 118 (117 + 1 for updated_at)

-- 2. Check timestamp consistency
SELECT id, created_at, updated_at 
FROM `sbx-uat.encarta.public.skus_master` 
WHERE created_at > updated_at; -- Should be empty

-- 3. Verify schema evolution worked
DESCRIBE `sbx-uat.encarta.public.skus_master`;
-- Should show both created_at and updated_at columns

-- 4. Verify aggregation counts
SELECT COUNT(*) FROM `sbx-uat.encarta.public.skus_uoms_agg`; -- Should match expected
SELECT COUNT(*) FROM `sbx-uat.encarta.public.skus_classifications_agg`; -- Should match expected
SELECT COUNT(*) FROM `sbx-uat.encarta.public.products_classifications_agg`; -- Should match expected
```

#### **Pipeline Health Checks**
```sql
-- Check streaming job status
SHOW JOBS;

-- Monitor lag and throughput
SELECT 
    job_name,
    status,
    start_time,
    end_time
FROM flink_jobs_history
WHERE job_name LIKE '%skus_master%';
```

## ⚠️ **Migration Risks and Mitigation**

### **Risk 1: Data Loss During Migration**
- **Mitigation**: Use dual-write pattern or complete backup before migration
- **Rollback**: Keep old tables until migration is fully validated

### **Risk 2: Schema Evolution Compatibility**
- **Mitigation**: Use FULL_TRANSITIVE compatibility mode in Schema Registry
- **Rollback**: Revert schema versions in Schema Registry if compatibility issues arise

### **Risk 3: Table Recreation Downtime**
- **Mitigation**: Use zero-downtime dual-write approach or schedule maintenance window
- **Rollback**: Keep backup tables and restore if needed
### **Risk 4: Downstream Dependencies**
- **Mitigation**: Identify and update all downstream consumers
- **Rollback**: Coordinate with dependent teams for rollback procedures

### **Risk 5: Performance Impact**
- **Mitigation**: Monitor query performance after migration
- **Rollback**: Optimize queries or revert if performance degrades

## 🚀 **Execution Timeline**

### **Pre-Migration (T-7 days)**
- [ ] Test migration in development environment
- [ ] Evolve schemas in Schema Registry (development)
- [ ] Identify all downstream dependencies
- [ ] Prepare rollback procedures (schema versions, table backups)
- [ ] Schedule maintenance window (if using Option C)

### **Migration Day (T-0)**
- [ ] **Hour 0**: Stop existing pipelines (if using Option C)
- [ ] **Hour 1**: Execute schema evolution in Schema Registry
- [ ] **Hour 2**: Deploy new table definitions or recreate tables
- [ ] **Hour 3**: Update and deploy SQL scripts
- [ ] **Hour 4**: Start new pipelines
- [ ] **Hour 5**: Validate data and performance
- [ ] **Hour 6**: Monitor and resolve issues

### **Post-Migration (T+1 to T+7 days)**
- [ ] Daily monitoring of pipeline health
- [ ] Validate data quality metrics
- [ ] Performance optimization if needed
- [ ] Clean up old backup tables

## 📊 **Monitoring and Alerting**

### **Key Metrics to Monitor**
```sql
-- Pipeline lag monitoring
SELECT 
    pipeline_name,
    AVG(processing_lag_ms) as avg_lag,
    MAX(processing_lag_ms) as max_lag
FROM pipeline_metrics
WHERE pipeline_name LIKE '%skus_master%'
GROUP BY pipeline_name;

-- Data freshness monitoring
SELECT 
    table_name,
    MAX(updated_at) as latest_update,
    COUNT(*) as record_count
FROM (
    SELECT 'skus_master' as table_name, updated_at FROM skus_master
    UNION ALL
    SELECT 'skus_uoms_agg' as table_name, updated_at FROM skus_uoms_agg
    UNION ALL
    SELECT 'skus_classifications_agg' as table_name, updated_at FROM skus_classifications_agg
    UNION ALL
    SELECT 'products_classifications_agg' as table_name, updated_at FROM products_classifications_agg
) t
GROUP BY table_name;
```

### **Alert Thresholds**
- **Pipeline Lag**: > 5 minutes
- **Data Freshness**: No updates in > 30 minutes
- **Error Rate**: > 1% failed records
- **Throughput**: < 80% of baseline

## 🔧 **Rollback Procedures**

### **Emergency Rollback**
```bash
# 1. Stop new pipelines immediately
flink cancel <job-id>

# 2. Restore old SQL scripts
git checkout HEAD~1 -- flink/encarta/

# 3. Restart old pipelines
flink run -f insert_skus_master.sql

# 4. Verify data flow restoration
# 5. Investigate and fix issues
```

### **Planned Rollback**
```sql
-- 1. Stop new pipelines gracefully
-- 2. Switch reads back to old tables
-- 3. Stop dual-write (if used)
-- 4. Restore old table schemas
-- 5. Restart old pipelines
```

## 📝 **Success Criteria**

### **Migration Complete When**
- [ ] All tables have both `created_at` and `updated_at` columns
- [ ] All SQL scripts updated and validated
- [ ] Pipeline throughput matches baseline
- [ ] Data quality metrics are green
- [ ] No data loss detected
- [ ] Downstream systems functioning normally
- [ ] Documentation updated

### **Performance Benchmarks**
- **Throughput**: >= 95% of baseline
- **Latency**: <= 105% of baseline
- **Error Rate**: <= 0.1%
- **Data Freshness**: <= 2 minutes

The migration is designed to be safe, reversible, and minimize business impact while providing enhanced timestamp tracking capabilities for the streaming pipeline.
