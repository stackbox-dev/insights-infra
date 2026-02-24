# Quick Setup Guide - StarRocks Sink Connector

This guide will help you quickly set up StarRocks as a sink connector for replicating tables from Kafka.

## Prerequisites Checklist

- [ ] Node.js >= 18.0.0 installed
- [ ] Access to Kafka Connect cluster
- [ ] StarRocks cluster with FE and BE nodes
- [ ] kubectl access to K8s cluster (for credentials)
- [ ] Kafka topics with Avro schema in Schema Registry

## Step 1: Install Dependencies

```bash
cd clickhouse-supertables
npm install
```

## Step 2: Install StarRocks Connector Plugin

Download and install the StarRocks Kafka Connector plugin:

```bash
# Download the connector
wget https://github.com/StarRocks/starrocks-connector-for-kafka/releases/download/v1.0.3/starrocks-kafka-connector-1.0.3.jar

# Find your Kafka Connect pod
kubectl get pods -n kafka | grep cp-connect

# Copy connector to pod
kubectl cp starrocks-kafka-connector-1.0.3.jar kafka/<cp-connect-pod-name>:/usr/share/java/kafka-connect-starrocks/

# Restart Kafka Connect
kubectl rollout restart deployment/cp-connect -n kafka

# Wait for restart
kubectl rollout status deployment/cp-connect -n kafka

# Verify installation
curl http://localhost:8083/connector-plugins | jq '.[] | select(.class | contains("StarRocks"))'
```

Expected output:
```json
{
  "class": "com.starrocks.connector.kafka.StarRocksSinkConnector",
  "type": "sink",
  "version": "1.0.3"
}
```

## Step 3: Create StarRocks Database and Tables

Connect to StarRocks:

```bash
# Port forward StarRocks FE
kubectl port-forward -n starrocks svc/starrocks-fe 9030:9030

# Connect via MySQL client
mysql -h 127.0.0.1 -P 9030 -u root -p
```

Create database and sample tables:

```sql
-- Create database
CREATE DATABASE IF NOT EXISTS sbx_uat;

USE sbx_uat;

-- Example: WMS Inventory Events
CREATE TABLE wms_inventory_events_staging (
  event_id BIGINT,
  warehouse_id STRING,
  sku_id STRING,
  quantity INT,
  event_type STRING,
  event_timestamp DATETIME,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
)
DUPLICATE KEY(event_id)
DISTRIBUTED BY HASH(event_id) BUCKETS 10
PROPERTIES (
  "replication_num" = "3",
  "storage_medium" = "SSD"
);

-- Example: OMS Orders (with deduplication)
CREATE TABLE oms_ord (
  order_id STRING,
  customer_id STRING,
  order_date DATETIME,
  status STRING,
  total_amount DECIMAL(10,2),
  updated_at DATETIME
)
UNIQUE KEY(order_id)
DISTRIBUTED BY HASH(order_id) BUCKETS 16
PROPERTIES (
  "replication_num" = "3",
  "enable_persistent_index" = "true"
);

-- Example: Storage Bin Master
CREATE TABLE wms_storage_bin_master (
  bin_id STRING,
  warehouse_id STRING,
  zone STRING,
  aisle STRING,
  level INT,
  position INT,
  capacity INT,
  bin_type STRING,
  is_active BOOLEAN,
  updated_at DATETIME
)
UNIQUE KEY(bin_id, warehouse_id)
DISTRIBUTED BY HASH(bin_id) BUCKETS 8
PROPERTIES (
  "replication_num" = "2"
);
```

## Step 4: Create Environment Configuration

```bash
# Copy sample environment file
cp .sample-starrocks.env .my-starrocks.env

# Edit the file with your credentials
vim .my-starrocks.env
```

Required configuration:

```bash
CP_CONNECT_URL=http://localhost:8083
TOPIC_PREFIX=sbx_uat

STARROCKS_FE_HOST=starrocks-fe.example.com
STARROCKS_HTTP_PORT=8030
STARROCKS_QUERY_PORT=9030
STARROCKS_USER=root
STARROCKS_DATABASE=sbx_uat
STARROCKS_PASSWORD=your_password

SCHEMA_REGISTRY_URL=https://kafka.aivencloud.com:25655
SCHEMA_REGISTRY_AUTH=username:password
CLUSTER_USER_NAME=avnconnect
CLUSTER_PASSWORD=your_password
AIVEN_TRUSTSTORE_PASSWORD=secret
```

### Fetch Credentials from Kubernetes

```bash
# StarRocks password
kubectl get secret starrocks-admin -n kafka -o jsonpath='{.data.password}' | base64 --decode

# Schema Registry credentials
kubectl get secret aiven-credentials -n kafka -o jsonpath='{.data.userinfo}' | base64 --decode

# Kafka cluster credentials
kubectl get secret aiven-credentials -n kafka -o jsonpath='{.data.username}' | base64 --decode
kubectl get secret aiven-credentials -n kafka -o jsonpath='{.data.password}' | base64 --decode

# Truststore password
kubectl get secret kafka-truststore-secret -n kafka -o jsonpath='{.data.truststore-password}' | base64 --decode
```

## Step 5: Configure Port Forwarding

```bash
# Kafka Connect (required)
kubectl port-forward -n kafka svc/cp-connect 8083:8083 &

# StarRocks FE (optional - for verification)
kubectl port-forward -n starrocks svc/starrocks-fe 8030:8030 9030:9030 &
```

## Step 6: Launch StarRocks Manager

```bash
npm run starrocks -- --env .my-starrocks.env
```

Expected output:
```
StarRocks Sink Connector Manager ⭐
==================================
Host: starrocks-fe.example.com:8030
Database: sbx_uat
User: root
```

## Step 7: Deploy Connectors

In the interactive UI:

1. Navigate to **"Deploy New Connector"**
2. Choose one of:
   - **"Deploy All Sinks"** - Deploy all configured connectors
   - **Individual sink** - Deploy specific connector (e.g., `wms-inventory`)
3. Wait for deployment confirmation
4. Verify status shows **"RUNNING"** (green)

## Step 8: Verify Data Flow

### Check Connector Status

In the manager UI, select the deployed connector to view:
- Tasks running
- Messages processed
- Any errors

### Verify Data in StarRocks

```sql
-- Check row count
SELECT COUNT(*) FROM wms_inventory_events_staging;

-- View recent data
SELECT * FROM wms_inventory_events_staging 
ORDER BY event_timestamp DESC 
LIMIT 10;

-- Check data freshness
SELECT 
  MIN(event_timestamp) as earliest,
  MAX(event_timestamp) as latest,
  COUNT(*) as total_rows
FROM wms_inventory_events_staging;
```

### Monitor Stream Load Jobs

```sql
-- Check recent load jobs
SELECT * FROM information_schema.loads 
WHERE database_name = 'sbx_uat' 
ORDER BY create_time DESC 
LIMIT 20;

-- Check for failed loads
SELECT * FROM information_schema.loads 
WHERE database_name = 'sbx_uat' 
  AND state = 'FAILED'
ORDER BY create_time DESC;
```

## Step 9: Monitor Health

### Kafka Connect Logs

```bash
kubectl logs -f deployment/cp-connect -n kafka | grep StarRocks
```

### StarRocks FE Logs

```bash
kubectl logs -f statefulset/starrocks-fe -n starrocks
```

### Connector Metrics

```bash
# Get connector status
curl http://localhost:8083/connectors/sbx_uat-starrocks-wms-inventory/status | jq

# Get connector config
curl http://localhost:8083/connectors/sbx_uat-starrocks-wms-inventory/config | jq
```

## Troubleshooting

### Issue: Connector plugin not found

```bash
# Verify plugin installation
kubectl exec -it deployment/cp-connect -n kafka -- ls -la /usr/share/java/kafka-connect-starrocks/

# Check Kafka Connect configuration
kubectl exec -it deployment/cp-connect -n kafka -- cat /etc/kafka-connect/kafka-connect.properties | grep plugin.path
```

### Issue: Cannot connect to StarRocks FE

```bash
# Test connectivity from Kafka Connect pod
kubectl exec -it deployment/cp-connect -n kafka -- curl -v http://starrocks-fe.starrocks.svc.cluster.local:8030

# Check StarRocks FE status
kubectl get pods -n starrocks | grep fe
kubectl logs -n starrocks starrocks-fe-0
```

### Issue: Schema mismatch errors

```bash
# Compare Avro schema with StarRocks table
# 1. Get Avro schema from Schema Registry
curl -u username:password https://kafka.aivencloud.com:25655/subjects/sbx_uat.wms.public.inventory-value/versions/latest | jq

# 2. Get StarRocks table schema
mysql -h 127.0.0.1 -P 9030 -u root -p -e "SHOW CREATE TABLE sbx_uat.wms_inventory_events_staging\G"
```

## Performance Tuning

### Increase Connector Parallelism

Edit `starrocks-config.js`:

```javascript
performanceConfig: {
  'tasks.max': '3',  // Increase tasks
  'sink.properties.batch.size': '100000',  // Larger batches
  'sink.properties.batch.flush.interval.ms': '60000',  // Less frequent flushes
}
```

### Optimize StarRocks Tables

```sql
-- Reduce replication for better write performance
ALTER TABLE wms_inventory_events_staging 
SET ("replication_num" = "2");

-- Use SSD for hot data
ALTER TABLE oms_ord 
SET ("storage_medium" = "SSD");

-- Enable colocate for join optimization
ALTER TABLE wms_storage_bin_master 
SET ("colocate_with" = "storage_group");
```

## Next Steps

- [ ] Monitor data lag and throughput
- [ ] Set up alerting for connector failures
- [ ] Create materialized views in StarRocks for analytics
- [ ] Tune batch sizes based on data volume
- [ ] Set up additional sink connectors for other tables
- [ ] Configure backup and retention policies

## Resources

- [StarRocks Documentation](https://docs.starrocks.io/)
- [StarRocks Kafka Connector GitHub](https://github.com/StarRocks/starrocks-connector-for-kafka)
- [STARROCKS-README.md](STARROCKS-README.md) - Full documentation
- [Kafka Connect Documentation](https://docs.confluent.io/platform/current/connect/index.html)

## Need Help?

- Check logs in the manager UI
- Review [STARROCKS-README.md](STARROCKS-README.md) troubleshooting section
- Verify all prerequisites are met
- Check StarRocks cluster health
- Validate network connectivity between components
