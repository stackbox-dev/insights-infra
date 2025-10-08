#!/bin/bash

# Check if env file parameter is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <env-file>"
    echo "Example: $0 .sbx-uat.env"
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

# Define topic to table mappings as JSON
TOPIC_MAPPINGS='[
  {"namespace": "flink", "topic": "pick_drop_staging", "table": "wms_pick_drop_staging"}
]'

# Generate topics list using jq
TOPICS=$(echo "$TOPIC_MAPPINGS" | jq -r --arg prefix "$TOPIC_PREFIX" \
  '[.[] | "\($prefix).wms.\(.namespace).\(.topic)"] | join(",")')

# Generate topic2TableMap using jq
TOPIC_TABLE_MAP=$(echo "$TOPIC_MAPPINGS" | jq -r --arg prefix "$TOPIC_PREFIX" \
  '[.[] | "\($prefix).wms.\(.namespace).\(.topic)=\(.table)"] | join(",")')

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

# Check if port forwarding started successfully
if ! ps -p $PORT_FORWARD_PID > /dev/null; then
  echo "Port forwarding failed. Exiting."
  exit 1
fi


export CLICKHOUSE_ADMIN_PASSWORD=$(kubectl get secret clickhouse-admin -n kafka -o jsonpath='{.data.password}' | base64 --decode)
export SCHEMA_REGISTRY_AUTH=$(kubectl get secret aiven-credentials -n kafka -o jsonpath='{.data.userinfo}' | base64 --decode)
export CLUSTER_USER_NAME=$(kubectl get secret aiven-credentials -n kafka -o jsonpath='{.data.username}' | base64 --decode)
export CLUSTER_PASSWORD=$(kubectl get secret aiven-credentials -n kafka -o jsonpath='{.data.password}' | base64 --decode)
export AIVEN_TRUSTSTORE=$(kubectl get secret kafka-truststore-secret -n kafka -o jsonpath='{.data.truststore-password}' | base64 --decode)


if [ -z "$CLICKHOUSE_ADMIN_PASSWORD" ]; then
  echo "Error: CLICKHOUSE_ADMIN_PASSWORD environment variable is not set"
  exit 1
fi

if [ -z "$SCHEMA_REGISTRY_AUTH" ]; then
  echo "Error: SCHEMA_REGISTRY_AUTH environment variable is not set"
  exit 1
fi

if [ -z "$CLUSTER_USER_NAME" ]; then
  echo "Error: CLUSTER_USER_NAME environment variable is not set"
  exit 1
fi

if [ -z "$CLUSTER_PASSWORD" ]; then
  echo "Error: CLUSTER_PASSWORD environment variable is not set"
  exit 1
fi

if [ -z "$AIVEN_TRUSTSTORE" ]; then
  echo "Error: AIVEN_TRUSTSTORE environment variable is not set"
  exit 1
fi

# IMPORTANT: ClickHouse Connector Bug Workaround
# The ClickHouse connector has a bug where it only checks the first record's schema type 
# when processing batches. If the first record is a tombstone (null value) or schema-less,
# it incorrectly processes the entire batch as SCHEMA_LESS, causing timestamp fields to be
# formatted with locale-specific strings (e.g., "Dec 12, 2024, 12:08:21 PM") instead of 
# proper timestamp values. This leads to parsing errors in ClickHouse.
#
# Workaround: We filter out tombstone records using a transform to ensure all batched 
# records have proper schemas. Without this, the connector works with max.poll.records=1
# but fails with higher values when tombstones are present.
#
# Additionally, ensure Kafka Connect workers run with -Duser.timezone=UTC to prevent
# locale-specific date formatting issues.

curl -X PUT http://localhost:8083/connectors/clickhouse-connect-${TOPIC_PREFIX}-wms-pick-drop/config \
-H "Content-Type: application/json" \
-d  '{
      "connector.class": "com.clickhouse.kafka.connect.ClickHouseSinkConnector",
      "tasks.max": "3",
      "topics": "'"$TOPICS"'",
      
      "transforms": "dropNull",
      "transforms.dropNull.type": "org.apache.kafka.connect.transforms.Filter",
      "transforms.dropNull.predicate": "isNullRecord",
      "predicates": "isNullRecord",
      "predicates.isNullRecord.type": "org.apache.kafka.connect.transforms.predicates.RecordIsTombstone",
      
      "hostname": "'"$CLICKHOUSE_HOSTNAME"'",
      "port": "'"$CLICKHOUSE_PORT"'",
      "ssl": "true",
      "username": "avnadmin",
      "password": "'"$CLICKHOUSE_ADMIN_PASSWORD"'",
      "database": "'$CLICKHOUSE_DATABASE'",
      "exactlyOnce": "false",
      "topic2TableMap": "'"$TOPIC_TABLE_MAP"'",
      "clickhouseSettings": "date_time_input_format=best_effort,max_insert_block_size=100000",
      "bufferFlushTime": "30000",
      "bufferSize": "100000",
      
      "key.converter": "io.confluent.connect.avro.AvroConverter",
      "value.converter": "io.confluent.connect.avro.AvroConverter",
      "value.converter.schemas.enable": "true",
      "value.converter.use.logical.type.converters": "true",
      "key.converter.schema.registry.url": "'"$SCHEMA_REGISTRY_URL"'",
      "value.converter.schema.registry.url": "'"$SCHEMA_REGISTRY_URL"'",
      "key.converter.basic.auth.credentials.source": "USER_INFO",
      "value.converter.basic.auth.credentials.source": "USER_INFO",
      "key.converter.basic.auth.user.info": "'"$SCHEMA_REGISTRY_AUTH"'",
      "value.converter.basic.auth.user.info": "'"$SCHEMA_REGISTRY_AUTH"'",

      "errors.tolerance": "none",
      "errors.log.enable": "true",
      "errors.log.include.messages": "true",
      "errors.deadletterqueue.topic.name": "dlq-wms-clickhouse-pick-drop",
      "errors.deadletterqueue.topic.replication.factor": "3",

      "consumer.override.max.poll.records": "50000",
      "consumer.override.max.partition.fetch.bytes": "20971520",
      "consumer.security.protocol": "SASL_SSL",
      "consumer.sasl.mechanism": "SCRAM-SHA-512",
      "consumer.sasl.jaas.config": "org.apache.kafka.common.security.scram.ScramLoginModule required username=\"'"$CLUSTER_USER_NAME"'\" password=\"'"$CLUSTER_PASSWORD"'\";",
      "consumer.ssl.truststore.location": "/etc/kafka/secrets/kafka.truststore.jks",
      "consumer.ssl.truststore.password": "'"$AIVEN_TRUSTSTORE"'",
      "consumer.ssl.endpoint.identification.algorithm": ""
}'

# Stop port forwarding
echo "Stopping port forwarding..."
kill $PORT_FORWARD_PID

echo "Done."