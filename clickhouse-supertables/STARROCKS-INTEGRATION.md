# StarRocks Integration - Summary

## 📋 What Was Added

This integration adds **StarRocks** as a sink connector option alongside the existing ClickHouse connector, enabling you to replicate Kafka topics to both databases based on your use case.

## 📦 New Files Created

### Configuration & Scripts
1. **`starrocks-config.js`** - StarRocks sink configurations
   - Pre-configured sinks for WMS, OMS, TMS, Encarta
   - StarRocks-specific connector settings
   - Topic-to-table mappings

2. **`starrocks-manager.js`** - StarRocks connector manager
   - Interactive CLI for StarRocks connectors
   - Same UI as ClickHouse manager
   - Separate from ClickHouse manager

### Documentation
3. **`STARROCKS-README.md`** - Complete StarRocks guide
   - Features and capabilities
   - Installation instructions
   - Configuration examples
   - Troubleshooting
   - Performance tuning
   - ClickHouse vs StarRocks comparison

4. **`STARROCKS-SETUP.md`** - Quick setup guide
   - Step-by-step installation
   - Connector plugin setup
   - Table creation examples
   - Verification steps
   - Common issues and solutions

### Configuration Templates
5. **`.sample.env`** - StarRocks environment template
   - Pre-filled structure
   - Credential fetch commands
   - StarRocks-specific variables

### Updated Files
6. **`README.md`** - Updated main documentation
   - Multi-sink support overview
   - Quick start for both sinks
   - Comparison table

8. **`.sample.env`** - Enhanced with StarRocks config
   - Both ClickHouse and StarRocks sections
   - Clear separation of credentials

9. **`package.json`** - Added npm scripts
   - `npm run starrocks` - Launch StarRocks manager
   - `npm run manage` - Launch unified manager
   - Updated description

## 🚀 How to Use

### Option 1: StarRocks Manager (Dedicated)

```bash
# Create environment file
cp .sample-starrocks.env .my-starrocks.env

# Edit with your credentials
vim .my-starrocks.env

# Launch StarRocks manager
npm run starrocks -- --env .my-starrocks.env
```

### Option 2: Unified Manager

```bash
# Create environment file (supports both sinks)
cp .sample.env .my-env.env

# Edit with credentials for both databases
vim .my-env.env

# Launch for StarRocks
npm run manage -- --env .my-env.env --sink starrocks

# Launch for ClickHouse
npm run manage -- --env .my-env.env --sink clickhouse
```

### Option 3: Direct Execution

```bash
# StarRocks
./starrocks-manager.js --env .my-starrocks.env

# ClickHouse (existing)
./manager.js --env .my-clickhouse.env

# Unified
./unified-manager.js --env .my-env.env --sink starrocks
```

## 🎯 Pre-configured StarRocks Sinks

The following sink connectors are ready to deploy:

### WMS (Warehouse Management System)
- **wms-inventory** - Inventory events staging
- **wms-pick-drop** - Pick and drop operations
- **wms-storage** - Storage bins and areas
- **wms-orders** - Outbound orders and line items
- **wms-inventory-core** - Core inventory and handling units

### Other Services
- **oms** - Order Management (orders, lines, allocations)
- **encarta** - Product Master (SKUs, overrides)
- **tms** - Transport Management (invoices, trips)

## 🔧 Configuration Structure

### StarRocks Configuration (`starrocks-config.js`)

```javascript
const starrocksSinkConfigurations = {
  'wms-inventory': {
    service: 'wms',
    topicMappings: [
      { namespace: 'flink', topic: 'inventory_events_staging', table: 'wms_inventory_events_staging' }
    ],
    dlqTopic: 'dlq-wms-starrocks-inventory',
    performanceConfig: starrocksDefaultPerformanceConfig
  },
  // ... more configurations
};
```

### Environment Variables Required

```bash
# StarRocks Connection
STARROCKS_FE_HOST=starrocks-fe.example.com
STARROCKS_HTTP_PORT=8030
STARROCKS_QUERY_PORT=9030
STARROCKS_USER=root
STARROCKS_PASSWORD=your_password
STARROCKS_DATABASE=sbx_uat

# Kafka (shared with ClickHouse)
TOPIC_PREFIX=sbx_uat
CP_CONNECT_URL=http://localhost:8083
SCHEMA_REGISTRY_URL=https://kafka.example.com:25655
SCHEMA_REGISTRY_AUTH=username:password
CLUSTER_USER_NAME=avnconnect
CLUSTER_PASSWORD=your_password
AIVEN_TRUSTSTORE_PASSWORD=secret
```

## 📊 Comparison: When to Use Each

| Use Case | ClickHouse | StarRocks |
|----------|-----------|-----------|
| **Append-only events** | ✅ Best | ✅ Good |
| **Updates & deletes** | ⚠️ Limited | ✅ Native |
| **Complex joins** | ⚠️ Basic | ✅ Full SQL |
| **Time-series data** | ✅ Excellent | ✅ Good |
| **Real-time dashboards** | ✅ Good | ✅ Excellent |
| **High concurrency** | ✅ Good | ✅ Better |
| **Compression** | ✅ Best | ✅ Good |
| **Data deduplication** | ⚠️ Manual | ✅ Automatic |

### Recommendation

- **Use ClickHouse for**: Logs, metrics, append-only events, time-series
- **Use StarRocks for**: Master data, transactional tables, OLAP with joins
- **Use Both**: Replicate to both for different query patterns!

## 🔍 Key Differences

### Connector Class
- **ClickHouse**: `com.clickhouse.kafka.connect.ClickHouseSinkConnector`
- **StarRocks**: `com.starrocks.connector.kafka.StarRocksSinkConnector`

### Table Mapping Format
- **ClickHouse**: `topic=table` (e.g., `sbx_uat.wms.public.inventory=wms_inventory`)
- **StarRocks**: `topic:table` (e.g., `sbx_uat.wms.public.inventory:wms_inventory`)

### Connection Properties
- **ClickHouse**: `hostname`, `port`, `username`, `password`
- **StarRocks**: `starrocks.http.url`, `starrocks.query.url`, `starrocks.user`, `starrocks.password`

### Loading Method
- **ClickHouse**: Direct INSERT via HTTP
- **StarRocks**: Stream Load API

## 📝 Adding New Sinks

### For StarRocks

Edit `starrocks-config.js`:

```javascript
'my-new-service': {
  service: 'my_service',
  topicMappings: [
    { namespace: 'public', topic: 'my_topic', table: 'my_table' },
    { namespace: 'public', topic: 'another_topic', table: 'another_table' }
  ],
  dlqTopic: 'dlq-my-service-starrocks',
  performanceConfig: starrocksDefaultPerformanceConfig
}
```

### Create StarRocks Table

```sql
CREATE TABLE my_database.my_table (
  id BIGINT,
  name STRING,
  value INT,
  updated_at DATETIME
)
DUPLICATE KEY(id)  -- or UNIQUE KEY or AGGREGATE KEY
DISTRIBUTED BY HASH(id) BUCKETS 10
PROPERTIES (
  "replication_num" = "3"
);
```

## 🛠️ Prerequisites for StarRocks

### 1. Install StarRocks Kafka Connector

```bash
wget https://github.com/StarRocks/starrocks-connector-for-kafka/releases/download/v1.0.3/starrocks-kafka-connector-1.0.3.jar
kubectl cp starrocks-kafka-connector-1.0.3.jar kafka/<cp-connect-pod>:/usr/share/java/kafka-connect-starrocks/
kubectl rollout restart deployment/cp-connect -n kafka
```

### 2. Verify Plugin Installation

```bash
curl http://localhost:8083/connector-plugins | jq '.[] | select(.class | contains("StarRocks"))'
```

### 3. Port Forwarding

```bash
kubectl port-forward -n kafka svc/cp-connect 8083:8083
kubectl port-forward -n starrocks svc/starrocks-fe 8030:8030 9030:9030
```

## 📚 Documentation Reference

- **[README.md](README.md)** - Main documentation (updated for multi-sink)
- **[STARROCKS-README.md](STARROCKS-README.md)** - StarRocks complete guide
- **[STARROCKS-SETUP.md](STARROCKS-SETUP.md)** - Step-by-step setup
- **[CLICKHOUSE-CLI-README.md](CLICKHOUSE-CLI-README.md)** - ClickHouse CLI tool
- **[.sample.env](.sample.env)** - sink environment template

## 🎉 Benefits of This Integration

1. **Flexibility** - Choose the right database for each workload
2. **No Breaking Changes** - Existing ClickHouse setup still works
3. **Unified Interface** - Same UI for both sinks
4. **Easy Migration** - Replicate to both during transition
5. **Performance** - Optimized configs for each database
6. **Well Documented** - Complete guides for both options

## 🚦 Next Steps

1. ✅ **Setup Environment** - Create `.env` file with StarRocks credentials
2. ✅ **Install Connector** - Add StarRocks plugin to Kafka Connect
3. ✅ **Create Tables** - Define StarRocks table schemas
4. ✅ **Launch Manager** - Start StarRocks manager UI
5. ✅ **Deploy Connectors** - Deploy sinks via the UI
6. ✅ **Verify Data** - Check data flowing into StarRocks tables
7. ✅ **Monitor** - Track connector status and performance

## 💡 Tips

- Start with a few tables (e.g., `wms-inventory`) to test
- Monitor initial load performance
- Adjust batch sizes in config based on data volume
- Use UNIQUE KEY in StarRocks for deduplication
- Consider replicating critical tables to both databases
- Set up alerts for connector failures

## 🆘 Getting Help

- Check **[STARROCKS-SETUP.md](STARROCKS-SETUP.md)** for detailed setup
- Review **[STARROCKS-README.md](STARROCKS-README.md)** troubleshooting section
- Verify connector plugin installation
- Check Kafka Connect and StarRocks logs
- Ensure network connectivity between components

## 📞 Quick Commands

```bash
# Install and start
npm install
npm run starrocks -- --env .my-env.env

# Check connector status
curl http://localhost:8083/connectors | jq

# Monitor StarRocks
mysql -h 127.0.0.1 -P 9030 -u root -p

# View load jobs
SELECT * FROM information_schema.loads ORDER BY create_time DESC LIMIT 10;
```

---

**You can now replicate Kafka topics to both ClickHouse and StarRocks! 🎉**
