# ClickHouse Sink Connector Manager

Interactive CLI tool for managing ClickHouse sink connectors in Kafka Connect.

## Features

- 🎨 **Interactive UI** - React-powered terminal interface
- 📊 **Real-time Status** - Auto-refreshing connector status every 5 seconds
- 🚀 **Easy Deployment** - Deploy single or all sink connectors with one click
- ⚡ **Quick Actions** - Restart, pause, resume, or delete connectors
- 📝 **Detailed View** - View connector details, tasks, and error traces
- 🔄 **Live Updates** - See connector state changes in real-time

## Prerequisites

- Node.js >= 18.0.0
- Access to Kafka Connect API
- Environment configuration file

## Installation

```bash
cd clickhouse-supertables
npm install
```

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

## License

ISC
