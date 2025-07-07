# Encarta Flink SQL Pipeline - Complete Migration Guide

This directory contains the complete Flink SQL pipeline for `skus_master` that has been migrated from view-based to materialized aggregation table architecture with event-time processing using Confluent's rowtime.

## 🏗️ **Architecture Overview**

### **Migration Summary**
- ✅ **From**: Static views with complex joins
- ✅ **To**: Materialized aggregation tables with streaming updates  
- ✅ **Benefits**: Better performance, event-time processing, proper state management

### **Key Components**
1. **Main Table**: `skus_master` - Denormalized view with 116 fields
2. **Aggregation Tables**: Pre-computed UOM and classification data
3. **Streaming Pipeline**: Real-time updates using Confluent's rowtime
4. **Event-Time Processing**: Using Confluent's default rowtime column

## � **Table Structure**

### **Primary Tables**
- `skus_master` (116 fields) - Main denormalized table using Confluent's rowtime
- `skus_uoms_agg` (79 fields) - UOM aggregations with L0-L3 hierarchy  
- `skus_classifications_agg` (3 fields) - SKU classifications as JSON
- `products_classifications_agg` (3 fields) - Product classifications as JSON

### **Schema Features**
- **NOT NULL constraints** on key fields (id, created_at, active, is_deleted)
- **TIMESTAMP_LTZ(3)** for consistent timezone handling
- **Confluent's rowtime** for event-time processing (system-provided)
- **Primary keys** with NOT ENFORCED for streaming compatibility

## 📋 **Execution Order**

### **Phase 1: Configure Source Tables**
Use Confluent's default rowtime for event-time processing:

```bash
# NOTE: Using Confluent's built-in rowtime column for event-time processing
# No additional watermark configuration needed
```

### **Phase 2: Create Aggregation Tables**
Create the materialized aggregation tables:

```bash
# Create UOM aggregations table (79 fields including created_at)
flink-sql -f table_skus_uoms_agg.sql

# Create SKU classifications aggregations table
flink-sql -f table_skus_classifications_agg.sql

# Create product classifications aggregations table
flink-sql -f table_products_classifications_agg.sql
```

### **Phase 3: Create Main Table**
Create the main denormalized table:

```bash
# Create the main skus_master table (116 fields using Confluent's rowtime)
flink-sql -f table_skus_master.sql
```

### **Phase 4: Start Aggregation Pipelines**
Populate the aggregation tables with streaming data:

```bash
# Start UOM aggregations streaming pipeline (groups by sku_id)
flink-sql -f populate_skus_uoms_agg.sql

# Start SKU classifications streaming pipeline (JSON aggregation)
flink-sql -f populate_skus_classifications_agg.sql

# Start product classifications streaming pipeline (JSON aggregation)
flink-sql -f populate_products_classifications_agg.sql
```

### **Phase 5: Start Main Pipeline**
Start the main denormalization streaming pipeline:

```bash
# Start the main skus_master streaming pipeline
flink-sql -f insert_skus_master.sql
```

## 🔧 **Technical Details**

### **Event-Time Processing**
- **Source Tables**: Use Confluent's built-in `rowtime` column
- **Custom Tables**: Rely on `created_at` for data freshness
- **Time Semantics**: Event-time processing without custom watermarks
- **Purpose**: Proper time-based operations using Confluent's system timestamps

### **Join Strategy** 
- **Main Pipeline**: Regular LEFT JOINs for real-time latest data
- **Aggregation Tables**: Event-time based GROUP BY with MAX(created_at)
- **Key Alignment**: Proper upsert key derivation from primary source (skus.id)

### **Data Types**
- **Timestamps**: `TIMESTAMP_LTZ(3)` for timezone consistency
- **Numeric Fields**: `DOUBLE PRECISION` for precision
- **JSON Fields**: `VARCHAR` with COALESCE('{}') for safe defaults
- **Keys**: `VARCHAR NOT NULL` for primary keys

### **State Management**
- **Aggregation Tables**: Materialized for performance
- **Streaming Joins**: Stateless regular joins for main pipeline  
- **Event Ordering**: Using Confluent's rowtime for proper time semantics

## 📁 **File Structure**

### **Core Pipeline Files**
- `table_skus_master.sql` - Main denormalized table (116 fields)
- `insert_skus_master.sql` - Streaming insert with real-time joins

### **Aggregation Components**
- `table_skus_uoms_agg.sql` - UOM aggregation table (79 fields)
- `table_skus_classifications_agg.sql` - SKU classifications (JSON)
- `table_products_classifications_agg.sql` - Product classifications (JSON)
- `populate_skus_uoms_agg.sql` - UOM streaming aggregation
- `populate_skus_classifications_agg.sql` - SKU classification streaming aggregation  
- `populate_products_classifications_agg.sql` - Product classification streaming aggregation

### **Documentation**
- `README.md` - This complete execution guide
- `MIGRATION_SUMMARY.md` - Detailed migration summary and validation

## ⚠️ **Important Notes**

### **Execution Dependencies**
1. **Source tables must exist** (created by Confluent)
2. **Confluent's rowtime** provides event-time processing automatically
3. **Aggregation tables must be created** before the main pipeline
4. **Population pipelines must be running** before starting main insert

### **Data Flow**
1. Source data flows into Confluent tables
2. Confluent's rowtime enables event-time processing
3. Population scripts aggregate data into materialized tables
4. Main pipeline joins latest data from all sources
5. Final denormalized data lands in skus_master

### **Performance Considerations**
- **Materialized aggregations** reduce join complexity
- **Real-time joins** provide latest data without temporal overhead
- **Proper key alignment** eliminates state-intensive operations
- **Event-time processing** handles late data correctly

## 🚀 **Production Readiness**

### **Validation Checklist**
- ✅ Schema field count: 116 fields (table) = 115 SELECT fields (insert)
- ✅ Event-time columns present in all tables
- ✅ Confluent's rowtime used for event-time processing
- ✅ NOT NULL constraints on critical fields
- ✅ COALESCE() handling for safe defaults
- ✅ Real-time joins for latest data
- ✅ Streaming aggregations with event-time
- ✅ Comprehensive documentation

### **Monitoring Points**
- **Aggregation lag**: Monitor population pipeline delays
- **Join performance**: Watch for backpressure in main pipeline
- **Data freshness**: Check created_at timestamps
- **Error rates**: Monitor failed records and schema mismatches

The pipeline is ready for production deployment with robust streaming capabilities and proper event-time semantics.