Here’s a detailed step-by-step guide with all the necessary YAML and configurations to set up OLTP to Kafka to ClickHouse streaming using Debezium, Kafka, and ClickHouse Sink Connector in your Kubernetes cluster.
# Documentation reference

Configure the Kafka client for authenticating to Google Cloud : https://cloud.google.com/managed-service-for-apache-kafka/docs/authentication-kafka#configure-kafka-client

# Step 1: Deploy Kafka Connect with Debezium

Kafka Connect is required to run both Debezium (for CDC) and ClickHouse Sink (for storing the data).

**1.1 Deploy Kafka Connect**

Create a **kafka-connect.yaml**

```bash
# Apply the manifest:
kubectl apply -f kafka/kafka-connect.yaml
```
# Step 2: Deploy Debezium Source Connector for PostgreSQL
Debezium monitors PostgreSQL and publishes changes to Kafka.

**2.1 Enable Logical Replication in PostgreSQL**

Run these SQL commands in your PostgreSQL database:

```bash
ALTER SYSTEM SET wal_level = logical;
ALTER SYSTEM SET max_replication_slots = 10;
ALTER SYSTEM SET max_wal_senders = 10;
SELECT pg_reload_conf();
```

Create a replication user:

```bash
CREATE USER debezium WITH REPLICATION ENCRYPTED PASSWORD '<your_password>';
GRANT USAGE ON SCHEMA public TO debezium;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO debezium;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO debezium;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO debezium;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO debezium;

```
**2.2 Create a Logical Replication Slot**
```bash
CREATE PUBLICATION dbz_publication FOR ALL TABLES;

SELECT * FROM pg_replication_slots;

SELECT * FROM pg_publication;

SELECT pg_drop_replication_slot('debezium');
DROP PUBLICATION dbz_publication;

```

**2.3 Deploy Debezium Connector**

Create **debezium-postgres.json**

To capture all tables in the database instead of specifying a single table, use:

```bash
"table.include.list": "public.*"
```

or remove this line entirely, as Debezium will default to capturing all tables in the database.

**Deploy the connector:**
```bash
# To create the connector use POST call
curl -X POST http://localhost:8083/connectors -H "Content-Type: application/json" -d @kafka/debezium-postgres.json

# To create the connector use PUT call
curl -X PUT http://localhost:8083/connectors/postgres-source/config \
     -H "Content-Type: application/json" \
     -d @kafka/debezium-postgres-update.json

```

# Step 3: Deploy ClickHouse
ClickHouse will receive data from Kafka.

**3.1 Deploy ClickHouse**

Create **clickhouse.yaml**

```bash
helm show values oci://registry-1.docker.io/bitnamicharts/clickhouse > clickhouse/helm/values.yaml

# here check the config for clickhouse from config.xml and add it in values.yaml
helm install clickhouse oci://registry-1.docker.io/bitnamicharts/clickhouse -f clickhouse/helm/values.yaml -n kafka

helm upgrade clickhouse oci://registry-1.docker.io/bitnamicharts/clickhouse -f clickhouse/helm/values.yaml -n kafka
```

# Step 4: Deploy ClickHouse Sink Connector
This connector will pull data from Kafka and insert it into ClickHouse.

**4.1 Create a Table in ClickHouse**

Run the following SQL in ClickHouse:
```bash
CREATE DATABASE sbx;
CREATE TABLE sbx.wms (
    id Int64,
    name String,
    created_at DateTime
) ENGINE = MergeTree()
ORDER BY id;
```

**4.2 Deploy ClickHouse Sink Connector**

Create **clickhouse-sink.json**

Deploy the connector:
```bash
curl -X POST http://cp-connect:8083/connectors -H "Content-Type: application/json" -d @clickhouse-sink.json
```


# Step 5: Verify the Setup
**5.1 Check Kafka Topics**

```bash
kubectl exec -it <kafka-pod-name> -n dev -- kafka-topics.sh --list --bootstrap-server cp-kafka:9092
```

You should see a topic like postgres.public.your_table.


**5.2 Consume Messages from Kafka**
```bash
kubectl exec -it <kafka-pod-name> -n dev -- kafka-console-consumer.sh --topic postgres.public.ccs_cedge --from-beginning --bootstrap-server cp-kafka:9092
```

**5.3 Verify Data in ClickHouse**
```bash
clickhouse-client --host clickhouse --query "SELECT * FROM your_db.your_table;"
```


https://cloud.google.com/managed-service-for-apache-kafka/docs/authentication-kafka#gcloud


"table.exclude.list": "public.payload_storage,public.storage_audit,public.webhook_invocation_event,public.webhook_invocation,public.ccs_schema_migration,public.iot_schema_migration,public.yms_schema_migration,public.tasks_schema_migration,public.assets_schema_migration,public.cincout_schema_migration,public.storage_schema_migration,public.webhooks_schema_migration,public.analytics_schema_migration,public.breakbulk_schema_migration,public.webhook_registry", 




curl -s http://localhost:8083/connector-plugins | jq -r '.[]'

io.confluent.connect.jdbc.JdbcSinkConnector
io.confluent.connect.jdbc.JdbcSourceConnector
io.debezium.connector.postgresql.PostgresConnector
org.apache.kafka.connect.mirror.MirrorCheckpointConnector
org.apache.kafka.connect.mirror.MirrorHeartbeatConnector
org.apache.kafka.connect.mirror.MirrorSourceConnector


SELECT
    name,
    value
FROM system.settings
WHERE name = 'max_threads'

SHOW TABLES FROM system


