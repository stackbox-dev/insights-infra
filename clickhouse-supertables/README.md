# Multi-Sink Connector Manager 🚀⭐

Interactive CLI tool for managing **ClickHouse** and **StarRocks** sink connectors in Kafka Connect. Replicate data from Kafka topics to multiple analytical databases for different use cases.

## 📚 Documentation

- **[ClickHouse Manager](README.md)** - This file (ClickHouse-specific details)
- **[StarRocks Manager](STARROCKS-README.md)** - StarRocks-specific guide
- **[ClickHouse CLI](CLICKHOUSE-CLI-README.md)** - SQL execution tool for ClickHouse

## 🎯 Choose Your Sink

### ClickHouse 🚀
Best for:
- Append-only workloads
- Time-series data & log analytics
- Maximum compression
- Simple aggregations

### StarRocks ⭐  
Best for:
- Real-time OLAP with updates/deletes
- Complex multi-table joins
- High-concurrency dashboards
- Transactional analytics

## Features

- 🎨 **Interactive UI** - React-powered terminal interface
- 📊 **Real-time Status** - Auto-refreshing connector status every 5 seconds
- 🚀 **Easy Deployment** - Deploy single or all sink connectors with one click
- ⚡ **Quick Actions** - Restart, pause, resume, or delete connectors
- 📝 **Detailed View** - View connector details, tasks, and error traces
- 🔄 **Live Updates** - See connector state changes in real-time
- 🔀 **Multi-Sink Support** - Manage both ClickHouse and StarRocks from one tool

## Prerequisites

- Node.js >= 18.0.0
- Access to Kafka Connect API
- ClickHouse and/or StarRocks cluster
- Environment configuration file

## Installation

```bash
cd clickhouse-supertables
npm install
```

## Quick Start

### ClickHouse Manager

```bash
# Start ClickHouse connector manager
npm run clickhouse -- --env .sbx-uat.env

# Or use the unified manager
### ClickHouse Manager

```bash
# Start ClickHouse connector manager
npm run clickhouse -- --env .sbx-uat.env
```

### StarRocks Manager

```bash
# Start StarRocks connector manager
npm run starrocks -- --env .sbx-uat.env
```

### Direct Node Execution

```bash
# ClickHouse
node manager.js --env .sbx-uat.env

# StarRocks
node starrocks-manager.js --env .sbx-uat.env
```

## Environment Setup

Copy and configure the sample environment file:

```bash
cp .sample.env .my-env.env
```

Edit `.my-env.env` with your credentials:

```bash
# Common settings
TOPIC_PREFIX=sbx_uat
CP_CONNECT_URL=http://localhost:8083
SCHEMA_REGISTRY_URL=https://kafka.example.com:25655

# ClickHouse (if using ClickHouse)
CLICKHOUSE_HOSTNAME=clickhouse.example.com
CLICKHOUSE_HTTP_PORT=8443
CLICKHOUSE_USER=default
CLICKHOUSE_DATABASE=sbx_uat
CLICKHOUSE_ADMIN_PASSWORD=your_password

# StarRocks (if using StarRocks)
STARROCKS_FE_HOST=starrocks-fe.example.com
STARROCKS_HTTP_PORT=8030
STARROCKS_QUERY_PORT=9030
STARROCKS_USER=root
STARROCKS_DATABASE=sbx_uat
STARROCKS_PASSWORD=your_password
```

See [.sample.env](.sample.env) for full configuration template.

## Usage

### Start the Manager

```bash
npm start -- --env <env-file>
```

### Examples

```bash
# Connect to SBX UAT environment
npm start -- --env .sbx-uat.env

# Connect to HUL DC Production
npm start -- --env .huldc-prod.env

# Connect to Samadhan Production
npm start -- --env .samadhan-prod.env
```

Alternatively, use node directly:

```bash
node manager.js --env .sbx-uat.env
```

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `↑` / `↓` | Navigate menu items |
| `Enter` | Select item |
| `r` | Refresh connector list |
| `ESC` | Go back to previous view |
| `q` or `Ctrl+C` | Quit application |

## UI Navigation

### Main View: Connector List

The main view shows all deployed ClickHouse sink connectors with their current status:

- **● Green** - Connector is RUNNING
- **❚❚ Yellow** - Connector is PAUSED
- **✗ Red** - Connector is FAILED
- **○ Gray** - Connector state is UNKNOWN

Each connector shows:
- Connector name
- Current state
- Number of tasks
- Failed tasks (if any)

### Actions Available

#### From Connector List

1. **Deploy New Connector** - Opens deployment menu
2. **Select Connector** - View detailed information

#### From Connector Detail View

1. **Restart Connector** - Restart the connector and all its tasks
2. **Pause Connector** - Pause the connector (if running)
3. **Resume Connector** - Resume the connector (if paused)
4. **Delete Connector** - Remove the connector from Kafka Connect

#### From Deploy View

1. **Deploy All Sinks** - Deploy all configured sinks at once
2. **Deploy Individual Sink** - Deploy a specific sink configuration

## Available Sink Configurations

- `wms-inventory` - WMS inventory events staging
- `wms-pick-drop` - WMS pick-drop operations
- `wms-storage` - WMS storage bin master data
- `wms-workstation` - WMS workstation events
- `wms-commons` - WMS common tables (handling units, workers, etc.)
- `wms-hu-events` - WMS handling unit events
- `wms-partitioned` - WMS partitioned tables
- `encarta` - Encarta SKU master and overrides
- `oms` - OMS orders and lines
- `tms` - TMS transport management
- `razum` - Razum market activity
- `backbone` - Backbone system data

## Environment Configuration

Each environment file (`.env`) must contain:

### Required Variables

```bash
# Kafka Connect API URL (manager.js connects to this to configure connectors)
CP_CONNECT_URL=http://localhost:8083

# Connector Configuration (these are used to configure the connector itself)
TOPIC_PREFIX=sbx_uat

# ClickHouse Connection
CLICKHOUSE_HOSTNAME=your-clickhouse-host.com
CLICKHOUSE_HTTP_PORT=22156
CLICKHOUSE_USER=avnadmin
CLICKHOUSE_DATABASE=sbx_uat

# Schema Registry
SCHEMA_REGISTRY_URL=https://your-schema-registry.com:22159

# Credentials
CLICKHOUSE_ADMIN_PASSWORD=your_password
SCHEMA_REGISTRY_AUTH=username:password
CLUSTER_USER_NAME=avnconnect
CLUSTER_PASSWORD=your_password
AIVEN_TRUSTSTORE_PASSWORD=secret
```

### Fetching Credentials from Kubernetes

If credentials are not set in the env file, fetch them using kubectl:

```bash
# ClickHouse password
kubectl get secret clickhouse-admin -n kafka -o jsonpath='{.data.password}' | base64 --decode

# Schema Registry auth
kubectl get secret aiven-credentials -n kafka -o jsonpath='{.data.userinfo}' | base64 --decode

# Cluster username
kubectl get secret aiven-credentials -n kafka -o jsonpath='{.data.username}' | base64 --decode

# Cluster password
kubectl get secret aiven-credentials -n kafka -o jsonpath='{.data.password}' | base64 --decode

# Truststore password
kubectl get secret kafka-truststore-secret -n kafka -o jsonpath='{.data.truststore-password}' | base64 --decode
```

## Port Forwarding (For localhost access)

If using `CP_CONNECT_URL=http://localhost:8083`, ensure port forwarding is active:

```bash
kubectl port-forward -n kafka svc/cp-connect 8083:8083
```

## Troubleshooting

### Cannot Connect to Kafka Connect

**Error**: `Failed to connect to Kafka Connect`

**Solutions**:
1. Verify `CP_CONNECT_URL` in your env file
2. Check if port forwarding is active (for localhost)
3. Ensure Kafka Connect pod is running

### Missing Environment Variables

**Error**: `Missing required environment variables`

**Solutions**:
1. Check all required variables are set in your env file
2. Fetch missing credentials from Kubernetes secrets
3. Use `.sample.env` as a template

### Connector Deployment Fails

**Error**: Connector fails to deploy

**Solutions**:
1. Check connector details in the UI for error traces
2. Verify ClickHouse and Kafka connectivity
3. Ensure topics exist in Kafka
4. Check Schema Registry accessibility

## Configuration Files

- `config.js` - Sink configurations and base settings
- `kafka-connect-client.js` - Kafka Connect REST API client
- `ui.js` - React UI components
- `manager.js` - Main entry point

## Architecture

The tool uses:
- **Ink** - React for CLIs
- **Kafka Connect REST API** - For connector management
- **ES Modules** - Modern JavaScript modules
- **Real-time Updates** - Auto-refresh every 5 seconds

## Development

### Adding a New Sink Configuration

Edit `config.js` and add your sink to `sinkConfigurations`:

```javascript
'my-new-sink': {
  service: 'my_service',
  topicMappings: [
    { namespace: 'public', topic: 'my_topic', table: 'my_table' }
  ],
  dlqTopic: 'dlq-my-sink',
  performanceConfig: defaultPerformanceConfig
}
```

### Modifying UI

Edit `ui.js` to customize the interface. Components are standard React components using Ink.

## StarRocks Support

This project now supports **StarRocks** as an additional sink connector. StarRocks provides:

- ✅ Real-time updates and deletes (UNIQUE KEY model)
- ✅ Full SQL support with complex joins
- ✅ High-concurrency OLAP queries
- ✅ Vectorized query engine
- ✅ MySQL protocol compatibility

### Using StarRocks

```bash
# Start StarRocks manager
npm run starrocks -- --env .sbx-uat.env

# Or use unified manager
npm run manage -- --env .sbx-uat.env --sink starrocks
```

### Configuration Files

**StarRocks-specific:**
- `starrocks-config.js` - StarRocks sink configurations
- `starrocks-manager.js` - StarRocks manager entry point
- `STARROCKS-README.md` - Complete StarRocks documentation

**Shared:**
- `config.js` - ClickHouse sink configurations
- `manager.js` - ClickHouse manager entry point
- `starrocks-manager.js` - StarRocks manager entry point
- `kafka-connect-client.js` - Kafka Connect REST API client
- `ui.js` - React UI components

### Setup Requirements

1. **Install StarRocks Connector Plugin** in Kafka Connect:
   ```bash
   wget https://github.com/StarRocks/starrocks-connector-for-kafka/releases/download/v1.0.3/starrocks-kafka-connector-1.0.3.jar
   kubectl cp starrocks-kafka-connector-1.0.3.jar kafka/cp-connect-pod:/usr/share/java/kafka-connect-starrocks/
   kubectl rollout restart deployment/cp-connect -n kafka
   ```

2. **Configure Environment Variables** for StarRocks:
   ```bash
   STARROCKS_FE_HOST=starrocks-fe.example.com
   STARROCKS_HTTP_PORT=8030
   STARROCKS_QUERY_PORT=9030
   STARROCKS_USER=root
   STARROCKS_PASSWORD=your_password
   STARROCKS_DATABASE=sbx_uat
   ```

3. **Create Tables in StarRocks**:
   ```sql
   CREATE DATABASE IF NOT EXISTS sbx_uat;
   
   CREATE TABLE sbx_uat.wms_inventory_events_staging (
     event_id BIGINT,
     warehouse_id STRING,
     sku_id STRING,
     quantity INT,
     event_timestamp DATETIME
   )
   DUPLICATE KEY(event_id)
   DISTRIBUTED BY HASH(event_id) BUCKETS 10;
   ```

For complete StarRocks documentation, see **[STARROCKS-README.md](STARROCKS-README.md)**.

## Related Tools

- **[ClickHouse CLI](CLICKHOUSE-CLI-README.md)** - Execute SQL queries and manage ClickHouse databases
- **ClickHouse Manager** - This tool (ClickHouse connectors)
- **StarRocks Manager** - StarRocks connector management

## License

ISC
