# Encarta Flink Scripts - Execution Guide

This directory contains Flink SQL scripts for building the Encarta data pipeline. Follow the execution order below to set up the complete pipeline.

## 📋 **Execution Order**

### **Phase 1: Create Base Tables**
Run these scripts first to create the main target tables:

```bash
# 1. Create the main skus_master table
flink-sql -f table_skus_master.sql
```

### **Phase 2: Create Aggregation Tables**
Create the materialized aggregation tables that will store pre-computed data:

```bash
# 2. Create UOM aggregations table
flink-sql -f table_skus_uoms_agg.sql

# 3. Create SKU classifications aggregations table  
flink-sql -f table_skus_classifications_agg.sql

# 4. Create product classifications aggregations table
flink-sql -f table_products_classifications_agg.sql
```

### **Phase 3: Start Aggregation Streams**
Start the streaming pipelines to continuously populate aggregation tables:

```bash
# 5. Start UOM aggregations streaming pipeline
flink-sql -f populate_skus_uoms_agg.sql

# 6. Start SKU classifications streaming pipeline
flink-sql -f populate_skus_classifications_agg.sql

# 7. Start product classifications streaming pipeline
flink-sql -f populate_products_classifications_agg.sql
```

### **Phase 4: Main Pipeline**
Start the main streaming pipeline:

```bash
# 8. Start the main skus_master streaming insert
flink-sql -f insert_skus_master.sql
```

## 🔄 **Continuous Operations**

All pipelines are now streaming continuously:

1. **UOM Aggregations**: `populate_skus_uoms_agg.sql` - Updates when `uoms` table changes
2. **SKU Classifications**: `populate_skus_classifications_agg.sql` - Updates when `classifications` table changes  
3. **Product Classifications**: `populate_products_classifications_agg.sql` - Updates when `product_classifications` table changes
4. **Main Pipeline**: `insert_skus_master.sql` - Updates when any source table changes

## 📊 **Monitoring & Maintenance**

### **Performance Monitoring**
- Monitor CFU consumption after implementing materialized tables
- Check for any remaining state-intensive operations
- Verify temporal join performance

## 🚨 **Troubleshooting**

### **Common Issues**

1. **Schema Mismatch Error**
   - Ensure all aggregation tables are created before running insert
   - Verify column counts match between source and target

2. **Primary Key Warnings**
   - Aggregation tables use proper primary keys (sku_id, product_id)
   - Main table uses sku id as primary key

3. **State-Intensive Operations**
   - Use materialized tables instead of views for aggregations
   - Ensure temporal joins are properly configured

### **Recovery Procedures**

1. **Restart Failed Jobs**
   ```bash
   # Stop and restart the main pipeline
   flink stop <job-id>
   flink-sql -f insert_skus_master.sql
   ```

2. **Rebuild Aggregations**
   ```bash
   # Stop and restart aggregation pipelines
   flink stop <aggregation-job-id>
   flink-sql -f populate_skus_uoms_agg.sql
   ```

## 📁 **File Descriptions**

| File | Purpose | When to Run |
|------|---------|-------------|
| `table_skus_master.sql` | Main denormalized table schema | Phase 1 - Once |
| `table_skus_uoms_agg.sql` | UOM aggregations table schema | Phase 2 - Once |
| `table_skus_classifications_agg.sql` | SKU classifications table schema | Phase 2 - Once |
| `table_products_classifications_agg.sql` | Product classifications table schema | Phase 2 - Once |
| `populate_skus_uoms_agg.sql` | UOM aggregations streaming pipeline | Phase 3 - Continuous |
| `populate_skus_classifications_agg.sql` | SKU classifications streaming pipeline | Phase 3 - Continuous |
| `populate_products_classifications_agg.sql` | Product classifications streaming pipeline | Phase 3 - Continuous |
| `insert_skus_master.sql` | Main streaming pipeline | Phase 4 - Continuous |

## 🎯 **Best Practices**

1. **Always run in order** - Dependencies must be created first
2. **Monitor resource usage** - Check CFU consumption after each phase
3. **Test with small datasets** - Validate logic before full deployment
4. **Use temporal joins** - Maintain data consistency across time
5. **Set up monitoring** - Track pipeline health and performance
6. **Plan for recovery** - Have rollback procedures ready

## 🔧 **Configuration Notes**

- All tables use `confluent` connector with `avro-registry` format
- Primary keys are defined but not enforced (`NOT ENFORCED`)
- Temporal joins use `FOR SYSTEM_TIME AS OF` for consistency
- COALESCE functions handle NULL values gracefully

---

**⚠️ Important**: Always test scripts in a development environment before deploying to production. The order of execution is critical for proper pipeline setup.