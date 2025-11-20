#!/bin/bash

# Check if env file parameter is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <env-file>"
    echo "Example: $0 digitaldc-prod.env"
    exit 1
fi

ENV_FILE="$1"

# Check if env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Environment file '$ENV_FILE' not found"
    exit 1
fi

# Load environment variables
source "$ENV_FILE"

# Validate required environment variables
if [ -z "$TOPIC_PREFIX" ]; then
    echo "Error: TOPIC_PREFIX not defined in $ENV_FILE"
    exit 1
fi

if [ -z "$CLICKHOUSE_HOSTNAME" ]; then
    echo "Error: CLICKHOUSE_HOSTNAME not defined in $ENV_FILE"
    exit 1
fi

if [ -z "$CLICKHOUSE_PORT" ]; then
    echo "Error: CLICKHOUSE_PORT not defined in $ENV_FILE"
    exit 1
fi

if [ -z "$SCHEMA_REGISTRY_URL" ]; then
    echo "Error: SCHEMA_REGISTRY_URL not defined in $ENV_FILE"
    exit 1
fi

if [ -z "$CLICKHOUSE_DATABASE" ]; then
    echo "Error: CLICKHOUSE_DATABASE not defined in $ENV_FILE"
    exit 1
fi

echo "Using TOPIC_PREFIX: $TOPIC_PREFIX"

# Define topic to table mappings for WMS HU Events
TOPIC_MAPPINGS='[
  {"topic": "public.handling_unit_event", "table": "wms_handling_unit_event"},
  {"topic": "public.handling_unit_quant_event", "table": "wms_handling_unit_quant_event"}
]'

# Generate topics list using jq
TOPICS=$(echo "$TOPIC_MAPPINGS" | jq -r --arg prefix "$TOPIC_PREFIX" \
  '[.[] | "\($prefix).wms.\(.topic)"] | join(",")')

# Generate topic2TableMap using jq
TOPIC_TABLE_MAP=$(echo "$TOPIC_MAPPINGS" | jq -r --arg prefix "$TOPIC_PREFIX" \
  '[.[] | "\($prefix).wms.\(.topic)=\(.table)"] | join(",")')

echo "Generated topics: $TOPICS"
echo "Generated topic2TableMap: $TOPIC_TABLE_MAP"

# Check current kubectl context and confirm with user
CURRENT_CONTEXT=$(kubectl config current-context)
echo "Current kubectl context: $CURRENT_CONTEXT"
read -p "Do you want to proceed with this context? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled. Please switch to the desired context first."
    exit 1
fi

NAMESPACE="kafka"
LABEL="app=cp-connect"
LOCAL_PORT=8083
REMOTE_PORT=8083

echo "Finding a kafka connect pod in namespace '$NAMESPACE' with label '$LABEL'..."

# Get the first pod matching the label
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "$LABEL" -o jsonpath="{.items[0].metadata.name}")

if [ -z "$POD_NAME" ]; then
  echo "No pods found with label '$LABEL' in namespace '$NAMESPACE'. Exiting."
  exit 1
fi

echo "Found pod: $POD_NAME"

# Start port-forwarding
echo "Starting port forward from localhost:$LOCAL_PORT to $POD_NAME:$REMOTE_PORT..."
kubectl port-forward -n "$NAMESPACE" pod/"$POD_NAME" "$LOCAL_PORT":"$REMOTE_PORT" &
PORT_FORWARD_PID=$!

# Wait a few seconds to ensure port forwarding is active
sleep 3

# Function to cleanup on exit
cleanup() {
    echo "Cleaning up..."
    if [ ! -z "$PORT_FORWARD_PID" ]; then
        echo "Stopping port forward (PID: $PORT_FORWARD_PID)..."
        kill $PORT_FORWARD_PID 2>/dev/null
    fi
}

# Set trap to call cleanup function on script exit
trap cleanup EXIT

# Fetch ClickHouse password from Kubernetes secret
echo "Fetching ClickHouse password..."
CLICKHOUSE_PASSWORD=$(kubectl get secret clickhouse-admin -n kafka -o jsonpath='{.data.password}' | base64 -d)

if [ -z "$CLICKHOUSE_PASSWORD" ]; then
    echo "Error: Failed to retrieve ClickHouse password from Kubernetes secret"
    exit 1
fi

echo "Creating/Updating ClickHouse connector for WMS HU Events..."

# Get Aiven cluster credentials
CLUSTER_USER_NAME=$(kubectl get secret aiven-credentials -n kafka -o jsonpath='{.data.username}' | base64 -d)
CLUSTER_PASSWORD=$(kubectl get secret aiven-credentials -n kafka -o jsonpath='{.data.password}' | base64 -d)
SCHEMA_REGISTRY_AUTH=$(kubectl get secret aiven-credentials -n kafka -o jsonpath='{.data.userinfo}' | base64 -d)

# Create connector configuration
curl -X PUT http://localhost:8083/connectors/clickhouse-connect-digitaldc_prod-wms-hu-events/config \
  -H "Content-Type: application/json" \
  -d '{
    "connector.class": "com.clickhouse.kafka.connect.ClickHouseSinkConnector",
    "topics": "'$TOPICS'",
    "topic2TableMap": "'$TOPIC_TABLE_MAP'",
    "hostname": "'$CLICKHOUSE_HOSTNAME'",
    "port": "'$CLICKHOUSE_PORT'",
    "database": "'$CLICKHOUSE_DATABASE'",
    "username": "'$CLICKHOUSE_USER'",
    "password": "'$CLICKHOUSE_PASSWORD'",
    "exactlyOnce": "false",
    "ssl": "true",
    "bufferSize": "100000",
    "bufferFlushTime": "30000",
    "clickhouseSettings": "date_time_input_format=best_effort,max_insert_block_size=100000",
    "transforms": "dropNull",
    "transforms.dropNull.type": "org.apache.kafka.connect.transforms.Filter",
    "transforms.dropNull.predicate": "isNullRecord",
    "predicates": "isNullRecord",
    "predicates.isNullRecord.type": "org.apache.kafka.connect.transforms.predicates.RecordIsTombstone",
    "errors.tolerance": "none",
    "errors.log.enable": "true",
    "errors.log.include.messages": "true",
    "key.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "key.converter.schema.registry.url": "'$SCHEMA_REGISTRY_URL'",
    "value.converter.schema.registry.url": "'$SCHEMA_REGISTRY_URL'",
    "key.converter.basic.auth.credentials.source": "USER_INFO",
    "value.converter.basic.auth.credentials.source": "USER_INFO",
    "key.converter.basic.auth.user.info": "'$SCHEMA_REGISTRY_AUTH'",
    "value.converter.basic.auth.user.info": "'$SCHEMA_REGISTRY_AUTH'",
    "value.converter.schemas.enable": "true",
    "value.converter.use.logical.type.converters": "true",
    "consumer.security.protocol": "SASL_SSL",
    "consumer.sasl.mechanism": "SCRAM-SHA-512",
    "consumer.sasl.jaas.config": "org.apache.kafka.common.security.scram.ScramLoginModule required username=\"'$CLUSTER_USER_NAME'\" password=\"'$CLUSTER_PASSWORD'\";",
    "consumer.ssl.truststore.location": "/etc/kafka/secrets/kafka.truststore.jks",
    "consumer.ssl.truststore.password": "secret",
    "consumer.ssl.endpoint.identification.algorithm": "",
    "consumer.override.max.poll.records": "50000",
    "consumer.override.max.partition.fetch.bytes": "20971520",
    "tasks.max": "2"
  }'

# Check if the request was successful
if [ $? -eq 0 ]; then
    echo "✅ ClickHouse connector for WMS HU Events created/updated successfully!"
    
    # Wait a moment for the connector to initialize
    sleep 5
    
    # Check connector status
    echo "Checking connector status..."
    curl -s http://localhost:8083/connectors/clickhouse-connect-digitaldc_prod-wms-hu-events/status | jq .
    
    echo ""
    echo "📋 Useful commands:"
    echo "  # Check connector status"
    echo "  curl -s http://localhost:8083/connectors/clickhouse-connect-digitaldc_prod-wms-hu-events/status | jq ."
    echo ""
    echo "  # Restart connector"
    echo "  curl -X POST http://localhost:8083/connectors/clickhouse-connect-digitaldc_prod-wms-hu-events/restart"
    echo ""
    echo "  # Delete connector"
    echo "  curl -X DELETE http://localhost:8083/connectors/clickhouse-connect-digitaldc_prod-wms-hu-events"
else
    echo "❌ Failed to create/update ClickHouse connector for WMS HU Events"
    exit 1
fi