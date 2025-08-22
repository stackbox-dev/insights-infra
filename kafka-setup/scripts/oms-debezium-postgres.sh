#!/bin/bash

set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "${SCRIPT_DIR}/common.sh"

# Function to display usage
usage() {
    cat << EOF
Usage: $0 --env <environment-file> [OPTIONS]

Deploy/Update OMS Debezium PostgreSQL connector

REQUIRED:
    --env <file>       Environment configuration file (e.g., .sbx-uat.env)

OPTIONS:
    --dry-run          Show configuration without deploying
    -h, --help         Show this help message

EXAMPLES:
    $0 --env .sbx-uat.env
    $0 --env .production.env --dry-run

EOF
}

# Parse command line arguments
ENV_FILE=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            ENV_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Load environment and check Kubernetes context
if ! load_env_file "$ENV_FILE"; then
    exit 1
fi

if ! check_kubernetes_context; then
    exit 1
fi

if ! fetch_kubernetes_credentials; then
    exit 1
fi

# Get OMS database password
print_info "Fetching OMS database credentials..."
OMS_DB_PASSWORD=$(fetch_db_password "$OMS_DB_PASSWORD_SECRET")
if [ $? -ne 0 ]; then
    exit 1
fi

# Find Kafka Connect pod
print_info "Finding Kafka Connect pod..."
POD_NAME=$(get_connect_pod)
if [ $? -ne 0 ]; then
    exit 1
fi

print_success "Found pod: $POD_NAME"

# Start port-forwarding
PORT_FORWARD_PID=$(start_port_forward "$POD_NAME" "$CONNECT_LOCAL_PORT" "$CONNECT_REMOTE_PORT")
if [ $? -ne 0 ]; then
    exit 1
fi

# Setup cleanup
cleanup_function() {
    cleanup "$PORT_FORWARD_PID"
}
setup_signal_handlers cleanup_function

# Define table list for easier maintenance
TABLE_LIST=$(cat <<EOF
public.ord,
public.line,
public.ord_state,
public.line_state,
public.allocation_line,
public.inv,
public.inv_line,
public.shipment_input,
public.shipment_output,
public.wms_dock_line
EOF
)

# Convert multiline to single line for JSON
TABLE_LIST_COMPACT=$(echo "$TABLE_LIST" | tr -d '\n' | sed 's/,$$//')

# Prepare connector configuration
CONNECTOR_CONFIG=$(cat <<EOF
{
      "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
      "database.hostname": "${OMS_DB_HOSTNAME}",
      "database.port": "${OMS_DB_PORT}",
      "database.user": "${OMS_DB_USER}",
      "database.password": "${OMS_DB_PASSWORD}",
      "database.dbname": "${OMS_DB_NAME}",
      "database.server.name": "${OMS_DB_NAME}",
      "plugin.name": "pgoutput",
      "table.include.list": "${TABLE_LIST_COMPACT}", 
      "publication.name": "${OMS_PUBLICATION_NAME}",
      "slot.name": "${OMS_SLOT_NAME}",

      "topic.prefix": "${OMS_TOPIC_PREFIX}",
      "slot.drop.on.stop": false,
      "schema.include.list": "public",
      "publication.autocreate.mode": "disabled",
      "tombstones.on.delete": false,
      "provide.transaction.metadata": false,
      "binary.handling.mode": "base64",
      "snapshot.mode": "when_needed",
      "incremental.snapshot.enabled": "true",
      "incremental.snapshot.chunk.size": "10000",
      "snapshot.locking.mode": "shared",
      
      "decimal.handling.mode": "precise",
      "time.precision.mode": "adaptive_time_microseconds",
      
      "errors.max.retries": "3",
      "errors.retry.delay.initial.ms": "1000",
      "errors.retry.delay.max.ms": "10000",
      "transforms": "filter,unwrap,ts2epoch",
      "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
      "transforms.unwrap.drop.tombstones": "true",
      "transforms.unwrap.delete.handling.mode": "drop",
      "transforms.unwrap.add.fields": "op,source.ts_ms,source.snapshot",
      "transforms.unwrap.add.fields.prefix": "__",
      "transforms.filter.type": "io.debezium.transforms.Filter",
      "transforms.filter.language": "jsr223.groovy",
      "transforms.filter.condition": "value.op != 'd'",
      "transforms.ts2epoch.type": "xyz.stackbox.kafka.transforms.AllTimestamptzToEpoch",
      
      "key.converter": "io.confluent.connect.avro.AvroConverter",
      "value.converter": "io.confluent.connect.avro.AvroConverter",
      "key.converter.schema.registry.url": "${SCHEMA_REGISTRY_URL}",
      "value.converter.schema.registry.url": "${SCHEMA_REGISTRY_URL}",
      "key.converter.basic.auth.credentials.source": "USER_INFO",
      "value.converter.basic.auth.credentials.source": "USER_INFO",
      "key.converter.basic.auth.user.info": "${SCHEMA_REGISTRY_AUTH}",
      "value.converter.basic.auth.user.info": "${SCHEMA_REGISTRY_AUTH}",
      "key.converter.auto.register.schemas": "true",
      "value.converter.auto.register.schemas": "true",
      "key.converter.use.latest.version": "true",
      "value.converter.use.latest.version": "true",
      "key.converter.schema.compatibility": "BACKWARD",
      "value.converter.schema.compatibility": "BACKWARD",
      
      "topic.creation.enable": "true",
      "topic.creation.default.replication.factor": 3,
      "topic.creation.default.partitions": 1,
      "topic.creation.default.cleanup.policy": "compact",
      "topic.creation.default.retention.ms": -1,
      "topic.creation.default.compression.type": "lz4",
      "topic.creation.default.retention.bytes": "-1",
      "topic.creation.default.include": ".*",
      "skipped.operations": "t",
      
      "producer.security.protocol": "SASL_SSL",
      "producer.sasl.mechanism": "SCRAM-SHA-512",
      "producer.sasl.jaas.config": "org.apache.kafka.common.security.scram.ScramLoginModule required username=\"${CLUSTER_USER_NAME}\" password=\"${CLUSTER_PASSWORD}\";",
      "producer.ssl.truststore.location": "/etc/kafka/secrets/kafka.truststore.jks",
      "producer.ssl.truststore.password": "secret",
      "producer.ssl.endpoint.identification.algorithm": "",
      "producer.max.request.size": "1048576",
      "producer.buffer.memory": "33554432",

      "read.only": true,
      "signal.enabled.channels": "kafka",
      "signal.kafka.bootstrap.servers": "${KAFKA_BOOTSTRAP_SERVERS}",
      "signal.kafka.groupId": "${OMS_SIGNAL_CONSUMER_GROUP}",
      "signal.kafka.topic": "${OMS_SIGNAL_TOPIC}",
      "signal.consumer.security.protocol": "SASL_SSL",
      "signal.consumer.sasl.mechanism": "SCRAM-SHA-512",
      "signal.consumer.sasl.jaas.config": "org.apache.kafka.common.security.scram.ScramLoginModule required username=\"${CLUSTER_USER_NAME}\" password=\"${CLUSTER_PASSWORD}\";",
      "signal.consumer.ssl.truststore.location": "/etc/kafka/secrets/kafka.truststore.jks",
      "signal.consumer.ssl.truststore.password": "secret",
      "signal.consumer.ssl.endpoint.identification.algorithm": ""
}
EOF
)

if [ "$DRY_RUN" = true ]; then
    print_color $YELLOW "[DRY RUN] Would deploy connector with configuration:"
    echo "$CONNECTOR_CONFIG" | jq .
    exit 0
fi

# Deploy/Update the connector
print_info "Deploying/Updating OMS Debezium connector: ${OMS_CONNECTOR_NAME}"

response=$(curl -s -w "\n%{http_code}" -X PUT \
    "${CONNECT_REST_URL}/connectors/${OMS_CONNECTOR_NAME}/config" \
    -H "Content-Type: application/json" \
    -d "$CONNECTOR_CONFIG")

status_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$status_code" = "200" ] || [ "$status_code" = "201" ]; then
    print_success "✅ Connector deployed/updated successfully!"
    
    # Get connector status
    print_info "Checking connector status..."
    sleep 2
    
    status_response=$(curl -s "${CONNECT_REST_URL}/connectors/${OMS_CONNECTOR_NAME}/status")
    connector_state=$(echo "$status_response" | jq -r '.connector.state' 2>/dev/null)
    
    if [ "$connector_state" = "RUNNING" ]; then
        print_success "Connector is RUNNING"
    else
        print_warning "Connector state: $connector_state"
        echo "Full status:"
        echo "$status_response" | jq .
    fi
else
    print_error "Failed to deploy/update connector (HTTP $status_code)"
    echo "Response: $body"
    exit 1
fi

print_info "\nUseful commands:"
echo "  # Check connector status"
echo "  curl -s ${CONNECT_REST_URL}/connectors/${OMS_CONNECTOR_NAME}/status | jq ."
echo ""
echo "  # Restart connector"
echo "  curl -X POST ${CONNECT_REST_URL}/connectors/${OMS_CONNECTOR_NAME}/restart"
echo ""
echo "  # Delete connector"
echo "  curl -X DELETE ${CONNECT_REST_URL}/connectors/${OMS_CONNECTOR_NAME}"
echo ""
echo "  # Trigger snapshot"
echo "  ./trigger-snapshots.sh --env $ENV_FILE -c oms -t \"public.ord\""