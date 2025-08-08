# Running the WMS Pick-Drop Enrichment Pipeline

## Overview

The WMS Pick-Drop enrichment pipeline is split into two separate jobs to handle historical data reprocessing and real-time streaming efficiently. This guide explains how to run these pipelines sequentially to ensure complete data processing without gaps or duplicates.

## Architecture

```
┌─────────────────────────┐     ┌─────────────────────────┐
│  Historical Pipeline    │     │  Real-time Pipeline     │
├─────────────────────────┤     ├─────────────────────────┤
│ • Bounded processing    │     │ • Unbounded streaming   │
│ • Processing time joins │     │ • Event time joins      │
│ • Processes all past    │────>│ • Continues from offset │
│   data up to latest     │     │ • Runs continuously     │
└─────────────────────────┘     └─────────────────────────┘
```

## Pipeline Files

1. **Historical Pipeline**: `sbx-uat/wms-pick-drop-enriched-historical.sql`
   - Processes all historical data from beginning to current latest offset
   - Uses processing time for temporal joins (ensures dimension data is available)
   - Completes and exits when done

2. **Real-time Pipeline**: `sbx-uat/wms-pick-drop-enriched-realtime.sql`
   - Processes new data continuously
   - Uses event time for proper temporal semantics
   - Resumes from where historical pipeline left off

## How to Run

### Prerequisites

1. Ensure Kafka credentials are set:
```bash
export KAFKA_USERNAME="your-username"
export KAFKA_PASSWORD="your-password"
export TRUSTSTORE_PASSWORD="truststore-password"
```

2. Verify source data is available:
```bash
# Check if pick_drop_basic topic has data
kubectl exec -n flink-studio flink-sql-gateway-0 -- \
  kafka-console-consumer \
  --bootstrap-server sbx-stag-kafka-stackbox.e.aivencloud.com:22167 \
  --topic sbx_uat.wms.internal.pick_drop_basic \
  --max-messages 1
```

### Step 1: Run Historical Pipeline

Start the historical pipeline to process all existing data:

```bash
python flink_sql_executor.py --sql-file sbx-uat/wms-pick-drop-enriched-historical.sql
```

**Monitor progress:**
```bash
# Get job ID from the output
JOB_ID=<job-id-from-output>

# Check job status
kubectl exec -n flink-studio flink-session-cluster-taskmanager-1-1 -- \
  curl -s http://flink-session-cluster-rest:8081/jobs/${JOB_ID} | jq '.state'
```

**Wait for completion:**
- The job state will change from `RUNNING` to `FINISHED`
- This may take several minutes to hours depending on data volume

### Step 2: Verify Historical Completion

Before starting the real-time pipeline, verify the historical job has completed:

```bash
# Check consumer group offset
kubectl exec -n flink-studio flink-sql-gateway-0 -- \
  kafka-consumer-groups \
  --bootstrap-server sbx-stag-kafka-stackbox.e.aivencloud.com:22167 \
  --group sbx-uat-wms-pick-drop-enriched \
  --describe
```

You should see:
- Committed offsets for all partitions
- Low or zero lag (indicates processing is complete)

### Step 3: Run Real-time Pipeline

Once historical is complete, start the real-time pipeline:

```bash
python flink_sql_executor.py --sql-file sbx-uat/wms-pick-drop-enriched-realtime.sql
```

This job will:
- Start from the committed offset (where historical left off)
- Run continuously processing new records
- Automatically resume from last position if restarted

**Monitor the job:**
```bash
# Get job ID
REALTIME_JOB_ID=<job-id-from-output>

# Check metrics
kubectl exec -n flink-studio flink-session-cluster-taskmanager-1-1 -- \
  curl -s http://flink-session-cluster-rest:8081/jobs/${REALTIME_JOB_ID}/metrics?get=numRecordsOut
```

## Zero Data Loss Guarantee

The pipelines use a shared Kafka consumer group (`sbx-uat-wms-pick-drop-enriched`) to ensure no data is lost:

1. **Historical pipeline** commits offsets as it processes
2. **Real-time pipeline** starts from the last committed offset
3. No gaps or duplicates between pipelines

## Handling Failures

### If Historical Pipeline Fails

```bash
# Simply restart - it will resume from last committed offset
python flink_sql_executor.py --sql-file sbx-uat/wms-pick-drop-enriched-historical.sql
```

### If Real-time Pipeline Fails

```bash
# Stop with savepoint (optional - for state preservation)
flink stop --savepointPath /tmp/savepoints ${REALTIME_JOB_ID}

# Restart (will resume from last committed offset)
python flink_sql_executor.py --sql-file sbx-uat/wms-pick-drop-enriched-realtime.sql

# Or restart from savepoint
flink run -s /tmp/savepoints/savepoint-xxx \
  --sql-file sbx-uat/wms-pick-drop-enriched-realtime.sql
```

## Monitoring and Validation

### Check Output Topic

Verify enriched data is being produced:

```bash
kubectl exec -n flink-studio flink-sql-gateway-0 -- \
  kafka-console-consumer \
  --bootstrap-server sbx-stag-kafka-stackbox.e.aivencloud.com:22167 \
  --topic sbx_uat.wms.public.pick_drop_summary \
  --from-beginning \
  --max-messages 10
```

### Monitor Consumer Lag

```bash
# Check lag for both pipelines
kubectl exec -n flink-studio flink-sql-gateway-0 -- \
  kafka-consumer-groups \
  --bootstrap-server sbx-stag-kafka-stackbox.e.aivencloud.com:22167 \
  --group sbx-uat-wms-pick-drop-enriched \
  --describe --all-topics
```

### Check for NULL Enrichments

```sql
-- In Flink SQL CLI or query tool
SELECT COUNT(*) as null_count
FROM pick_drop_summary
WHERE task_kind IS NULL 
  OR session_kind IS NULL
  OR worker_name IS NULL;
```

## Best Practices

1. **Always run historical first** - Dimension tables need time to build state
2. **Wait for completion** - Don't start real-time until historical finishes
3. **Monitor consumer groups** - Verify offsets are committed properly
4. **Check for NULLs** - Validate enrichment is working correctly
5. **Save job IDs** - Keep track for monitoring and troubleshooting

## Troubleshooting

### Issue: Real-time pipeline shows old data
**Solution**: Check if historical pipeline completed successfully. The real-time pipeline might be processing buffered data.

### Issue: NULL values in enriched output
**Solution**: 
- For historical: This shouldn't happen with processing time joins
- For real-time: May indicate dimension tables are behind - check their consumer lag

### Issue: Duplicate processing
**Solution**: Ensure only one instance of each pipeline is running. Check consumer group membership.

### Issue: Pipeline not starting
**Solution**: Check if previous job with same consumer group is still running:
```bash
kubectl get pods -n flink-studio | grep taskmanager
```

## Configuration Tuning

### For Large Historical Datasets

Edit `wms-pick-drop-enriched-historical.sql`:
```sql
SET 'parallelism.default' = '8';  -- Increase parallelism
SET 'table.exec.mini-batch.size' = '20000';  -- Larger batches
SET 'execution.checkpointing.interval' = '600000';  -- Less frequent checkpoints
```

### For High-Throughput Real-time

Edit `wms-pick-drop-enriched-realtime.sql`:
```sql
SET 'parallelism.default' = '6';  -- More parallel processing
SET 'table.exec.mini-batch.size' = '2000';  -- Smaller batches for lower latency
SET 'execution.checkpointing.interval' = '30000';  -- More frequent checkpoints
```

## Summary

By splitting the enrichment into historical and real-time pipelines:
- Historical data gets processed efficiently with processing time semantics
- Real-time data maintains proper event time semantics
- No data loss between pipelines through shared consumer groups
- Each pipeline is optimized for its specific use case

Follow this guide to ensure smooth, complete processing of your pick-drop enrichment pipeline.