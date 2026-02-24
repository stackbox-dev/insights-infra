# StarRocks Sink Connector Manager ⭐

Interactive CLI tool for managing StarRocks sink connectors in Kafka Connect. This tool enables real-time data replication from Kafka topics to StarRocks tables for high-performance analytics.

## Overview

StarRocks is a next-gen, high-performance analytical database. This connector manager helps you:
- Replicate critical operational data from Kafka to StarRocks
- Maintain real-time analytics capabilities alongside ClickHouse
- Manage multiple sink connectors through an interactive UI
- Monitor connector health and performance

## Features

- 🎨 **Interactive UI** - React-powered terminal interface
- 📊 **Real-time Status** - Auto-refreshing connector status every 5 seconds
- 🚀 **Easy Deployment** - Deploy single or all sink connectors with one click
- ⚡ **Quick Actions** - Restart, pause, resume, or delete connectors
- 📝 **Detailed View** - View connector details, tasks, and error traces
- 🔄 **Live Updates** - See connector state changes in real-time
- ⭐ **StarRocks Optimized** - Configured for StarRocks Stream Load API

## Prerequisites

- Node.js >= 18.0.0
- Access to Kafka Connect API
- StarRocks cluster (FE and BE nodes accessible)
- Environment configuration file
- StarRocks Kafka Connector plugin installed in Kafka Connect

## Installation

```bash
cd clickhouse-supertables
npm install
```

## StarRocks Kafka Connector Setup

### 1. Download StarRocks Connector

```bash
# Download the latest StarRocks Kafka Connector
wget https://github.com/StarRocks/starrocks-connector-for-kafka/releases/download/v1.0.6/starrocks-kafka-connector-1.0.6.jar

# Copy to Kafka Connect plugins directory
kubectl cp starrocks-kafka-connector-1.0.6.jar kafka/cp-connect-pod:/usr/share/java/kafka-connect-starrocks/
```

### 2. Restart Kafka Connect

```bash
kubectl rollout restart deployment/cp-connect -n kafka
```

### 3. Verify Plugin Installation

```bash
curl http://localhost:8083/connector-plugins | jq '.[] | select(.class | contains("StarRocks"))'
```

## Usage

### Start the StarRocks Manager

```bash
npm run starrocks -- --env <env-file>
```

### Examples

```bash
# Connect to SBX UAT environment
npm run starrocks -- --env .sbx-uat.env

# Connect to HUL DC Production
npm run starrocks -- --env .huldc-prod.env

# Connect to Samadhan Production
npm run starrocks -- --env .samadhan-prod.env
```

Alternatively, use node directly:

```bash
node starrocks-manager.js --env .sbx-uat.env
```

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `↑` / `↓` | Navigate menu items |
| `Enter` | Select item |
| `r` | Refresh connector list |
| `ESC` | Go back to previous view |
| `q` or `Ctrl+C` | Quit application |

## Available Sink Configurations

The following sink connectors are pre-configured for StarRocks:

### WMS (Warehouse Management System)
- `wms-inventory` - Inventory events staging table
- `wms-pick-drop` - Pick and drop operations
- `wms-storage` - Storage bin and area master data
- `wms-orders` - Outbound orders and line items
- `wms-inventory-core` - Core inventory and handling units

### OMS (Order Management System)
- `oms` - Orders, lines, and allocations

### Encarta (Product Master)
- `encarta` - SKU master and overrides

### TMS (Transport Management System)
- `tms` - Invoice and trip data

## Environment Configuration

Each environment file (`.env`) must contain both ClickHouse and StarRocks credentials:

### Required Variables for StarRocks

```bash
# Kafka Connect API URL
CP_CONNECT_URL=http://localhost:8083

# Topic Configuration (shared)
TOPIC_PREFIX=sbx_uat

# StarRocks Connection
STARROCKS_FE_HOST=starrocks-fe.example.com
STARROCKS_HTTP_PORT=8030
STARROCKS_QUERY_PORT=9030
STARROCKS_USER=root
STARROCKS_DATABASE=sbx_uat

# Schema Registry (shared with ClickHouse)
SCHEMA_REGISTRY_URL=https://your-schema-registry.com:22159

# Credentials
STARROCKS_PASSWORD=your_starrocks_password
SCHEMA_REGISTRY_AUTH=username:password
CLUSTER_USER_NAME=avnconnect
CLUSTER_PASSWORD=your_password
AIVEN_TRUSTSTORE_PASSWORD=secret
```

### Fetching Credentials from Kubernetes

```bash
# StarRocks password
kubectl get secret starrocks-admin -n kafka -o jsonpath='{.data.password}' | base64 --decode

# Schema Registry auth (shared)
kubectl get secret aiven-credentials -n kafka -o jsonpath='{.data.userinfo}' | base64 --decode

# Kafka credentials (shared)
kubectl get secret aiven-credentials -n kafka -o jsonpath='{.data.username}' | base64 --decode
kubectl get secret aiven-credentials -n kafka -o jsonpath='{.data.password}' | base64 --decode

# Truststore password (shared)
kubectl get secret kafka-truststore-secret -n kafka -o jsonpath='{.data.truststore-password}' | base64 --decode
```

## StarRocks Table Schema Requirements

### 1. Create Database

```sql
CREATE DATABASE IF NOT EXISTS sbx_uat;
```

### 2. Create Tables

StarRocks tables must match the Kafka topic schema. Example for inventory events:

```sql
CREATE TABLE sbx_uat.wms_inventory_events_staging (
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
  "storage_medium" = "SSD",
  "enable_persistent_index" = "true"
);
```

### 3. Key Considerations

- Use **DUPLICATE KEY** model for event tables (high insert throughput)
- Use **UNIQUE KEY** model for master data tables (deduplication)
- Use **AGGREGATE KEY** model for metrics/aggregation tables
- Set appropriate bucketing based on data volume
- Enable persistent index for better query performance

## Port Forwarding (For localhost access)

If using `CP_CONNECT_URL=http://localhost:8083`:

```bash
# Kafka Connect
kubectl port-forward -n kafka svc/cp-connect 8083:8083

# StarRocks FE (optional, for direct queries)
kubectl port-forward -n starrocks svc/starrocks-fe 8030:8030 9030:9030
```

## Troubleshooting

### Cannot Connect to Kafka Connect

**Error**: `Failed to connect to Kafka Connect`

**Solutions**:
1. Verify `CP_CONNECT_URL` in your env file
2. Check if port forwarding is active (for localhost)
3. Ensure Kafka Connect pod is running

### StarRocks Connector Plugin Not Found

**Error**: `Connector class not found: com.starrocks.connector.kafka.StarRocksSinkConnector`

**Solutions**:
1. Verify StarRocks connector JAR is in Kafka Connect plugins directory
2. Restart Kafka Connect after adding the plugin
3. Check connector plugins list: `curl http://localhost:8083/connector-plugins`

### Stream Load Failed

**Error**: `Stream load failed` or `HTTP 401 Unauthorized`

**Solutions**:
1. Verify StarRocks FE host and port are correct
2. Check StarRocks user credentials
3. Ensure StarRocks database exists
4. Verify network connectivity from Kafka Connect to StarRocks FE

### Table Schema Mismatch

**Error**: `Column not found` or `Type mismatch`

**Solutions**:
1. Ensure StarRocks table schema matches Kafka topic schema
2. Check Avro schema in Schema Registry
3. Verify column names and types are compatible
4. Use `sink.properties.columns` to map columns explicitly if needed

### Connector Deployment Fails

**Error**: Connector fails to deploy

**Solutions**:
1. Check connector details in the UI for error traces
2. Verify StarRocks cluster health
3. Check StarRocks FE and BE nodes are accessible
4. Ensure topics exist in Kafka
5. Validate Schema Registry accessibility
6. Review StarRocks audit logs

## Performance Tuning

### Connector Configuration

```javascript
// Adjust in starrocks-config.js
const performanceConfig = {
  'tasks.max': '3',  // Increase for higher parallelism
  'sink.properties.batch.size': '100000',  // Larger batches
  'sink.properties.batch.flush.interval.ms': '60000',  // Less frequent flushes
  'consumer.override.max.poll.records': '100000'
};
```

### StarRocks Table Properties

```sql
-- Optimize for write performance
ALTER TABLE wms_inventory_events_staging 
SET ("replication_num" = "2");  -- Reduce replication

-- Use SSD for hot data
ALTER TABLE wms_inventory_events_staging 
SET ("storage_medium" = "SSD");

-- Enable colocate for join optimization
ALTER TABLE wms_inventory_events_staging 
SET ("colocate_with" = "inventory_group");
```

## Architecture

### Data Flow

```
Kafka Topics (Avro) 
  → Kafka Connect 
    → StarRocks Connector 
      → StarRocks Stream Load API 
        → StarRocks Tables
```

### Components

- **Ink** - React for CLIs
- **Kafka Connect REST API** - Connector management
- **StarRocks Stream Load** - Efficient bulk loading
- **Avro Converter** - Schema evolution support
- **Real-time Updates** - Auto-refresh every 5 seconds

## Comparison: ClickHouse vs StarRocks

| Feature | ClickHouse | StarRocks |
|---------|-----------|-----------|
| **Query Performance** | Excellent (columnar) | Excellent (vectorized) |
| **Concurrent Queries** | Good | Better (MPP) |
| **Updates/Deletes** | Limited | Native support |
| **Data Deduplication** | Manual | Automatic (UNIQUE KEY) |
| **Joins** | Limited | Full SQL join support |
| **Real-time Analytics** | Good | Excellent |
| **Storage Format** | MergeTree | Columnar + Indexes |

### When to Use StarRocks

- ✅ Need frequent updates/deletes
- ✅ Require complex joins
- ✅ High concurrency workloads
- ✅ Real-time dashboard queries
- ✅ OLAP with transactional needs

### When to Use ClickHouse

- ✅ Append-only workloads
- ✅ Time-series data
- ✅ Log analytics
- ✅ Maximum compression needed
- ✅ Mature ecosystem

## Monitoring

### Check Connector Status

```bash
# List all StarRocks connectors
curl http://localhost:8083/connectors | jq '.[] | select(. | contains("starrocks"))'

# Get specific connector status
curl http://localhost:8083/connectors/sbx_uat-starrocks-wms-inventory/status | jq
```

### StarRocks Monitoring

```sql
-- Check load jobs
SELECT * FROM information_schema.loads 
WHERE database_name = 'sbx_uat' 
ORDER BY create_time DESC 
LIMIT 10;

-- Monitor table row counts
SELECT table_name, COUNT(*) as row_count 
FROM sbx_uat.wms_inventory_events_staging;

-- Check BE node load
SHOW BACKENDS\G
```

## Configuration Files

- `starrocks-config.js` - StarRocks sink configurations
- `starrocks-manager.js` - StarRocks manager entry point
- `kafka-connect-client.js` - Kafka Connect REST API client (shared)
- `ui.js` - React UI components (shared)
- `.sample.env` - Environment template with StarRocks config

## Development

### Adding a New StarRocks Sink

Edit `starrocks-config.js`:

```javascript
'my-new-sink': {
  service: 'my_service',
  topicMappings: [
    { namespace: 'public', topic: 'my_topic', table: 'my_table' }
  ],
  dlqTopic: 'dlq-my-service-starrocks',
  performanceConfig: starrocksDefaultPerformanceConfig
}
```

### Testing Locally

```bash
# 1. Start StarRocks locally (Docker)
docker run -d --name starrocks-fe \
  -p 8030:8030 -p 9030:9030 \
  starrocks/fe-ubuntu:latest

# 2. Port forward Kafka Connect
kubectl port-forward -n kafka svc/cp-connect 8083:8083

# 3. Run manager
npm run starrocks -- --env .local.env
```

## Related Tools

- **ClickHouse Manager** - Run with `npm run clickhouse -- --env .env`
- **ClickHouse CLI** - Run with `node clickhouse-cli.js --env .env`
- **StarRocks SQL Client** - Connect via `mysql -h localhost -P 9030 -u root`

## References

- [StarRocks Documentation](https://docs.starrocks.io/)
- [StarRocks Kafka Connector](https://github.com/StarRocks/starrocks-connector-for-kafka)
- [Kafka Connect Documentation](https://docs.confluent.io/platform/current/connect/index.html)
- [Stream Load API](https://docs.starrocks.io/docs/loading/StreamLoad/)

## License

ISC
