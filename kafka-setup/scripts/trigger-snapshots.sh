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

Trigger incremental snapshots for specific tables in Debezium connectors

REQUIRED:
    --env <file>       Environment configuration file (e.g., .sbx-uat.env)

OPTIONS:
    -c, --connector    Full connector name (e.g., source-sbx-uat-wms, source-samadhan-prod-backbone) - if not provided, will prompt
    -t, --tables       Comma-separated list of tables - if not provided, will prompt
    -f, --filter       Optional filter conditions for snapshot (e.g., "id > 1000")
    -d, --dry-run      Show what would be done without actually triggering snapshots
    -l, --list-only    Only list available connectors and their tables
    --create-topics-only Create signal topics only, don't trigger snapshots
    -h, --help         Show this help message

EXAMPLES:
    $0 --env .sbx-uat.env -c source-sbx-uat-wms -t "public.inventory,public.task"
    $0 --env .sbx-uat.env -c source-sbx-uat-encarta -t "public.skus" -f "updated_at > '2024-01-01'"
    $0 --env .sbx-uat.env -c source-sbx-uat-oms -t "public.po_oms_allocation"
    $0 --env .sbx-uat.env -c source-samadhan-prod-backbone -t "public.users"
    $0 --env .sbx-uat.env --list-only
    $0 --env .sbx-uat.env --dry-run -c source-sbx-uat-wms -t "public.inventory"
    $0 --env .sbx-uat.env -c source-sbx-uat-wms --create-topics-only

EOF
}

# Parse command line arguments
ENV_FILE=""
CONNECTOR=""
TABLES=""
FILTER=""
DRY_RUN=false
LIST_ONLY=false
CREATE_TOPICS_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            ENV_FILE="$2"
            shift 2
            ;;
        -c|--connector)
            CONNECTOR="$2"
            shift 2
            ;;
        -t|--tables)
            TABLES="$2"
            shift 2
            ;;
        -f|--filter)
            FILTER="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -l|--list-only)
            LIST_ONLY=true
            shift
            ;;
        --create-topics-only)
            CREATE_TOPICS_ONLY=true
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

# Function to get connector configuration
get_connector_config() {
    local connector_name=$1
    curl -s -X GET "${CONNECT_REST_URL}/connectors/${connector_name}/config" 2>/dev/null
}

# Function to list all connectors
list_connectors() {
    curl -s -X GET "${CONNECT_REST_URL}/connectors" 2>/dev/null | jq -r '.[]' 2>/dev/null || echo ""
}

# Function to extract tables from connector config
extract_tables() {
    local config=$1
    echo "$config" | jq -r '.["table.include.list"] // ""' 2>/dev/null | tr ',' '\n' | sort
}

# Function to get topic prefix from connector config
get_topic_prefix() {
    local config=$1
    echo "$config" | jq -r '.["topic.prefix"] // ""' 2>/dev/null
}

# Function to check if signal.kafka.topic is configured
check_signal_topic_config() {
    local config=$1
    local signal_topic=$(echo "$config" | jq -r '.["signal.kafka.topic"] // ""' 2>/dev/null)
    local enabled_channels=$(echo "$config" | jq -r '.["signal.enabled.channels"] // ""' 2>/dev/null)
    
    if [ -z "$signal_topic" ]; then
        return 1
    fi
    
    if [[ ! "$enabled_channels" == *"kafka"* ]]; then
        return 1
    fi
    
    echo "$signal_topic"
    return 0
}

# List available connectors
print_info "Available Debezium connectors:"
AVAILABLE_CONNECTORS=$(list_connectors)

if [ -z "$AVAILABLE_CONNECTORS" ]; then
    print_error "No connectors found in Kafka Connect"
    exit 1
fi

# Filter for Debezium connectors
DEBEZIUM_CONNECTORS=""
for conn in $AVAILABLE_CONNECTORS; do
    # Check if it's one of our configured connectors
    if [[ "$conn" == "$WMS_CONNECTOR_NAME" ]] || \
       [[ "$conn" == "$ENCARTA_CONNECTOR_NAME" ]] || \
       [[ "$conn" == "$BACKBONE_CONNECTOR_NAME" ]] || \
       [[ "$conn" == "$OMS_CONNECTOR_NAME" ]]; then
        print_success "  - $conn"
        DEBEZIUM_CONNECTORS="$DEBEZIUM_CONNECTORS $conn"
    fi
done

# If list-only mode, show tables for each connector and exit
if [ "$LIST_ONLY" = true ]; then
    for conn in $DEBEZIUM_CONNECTORS; do
        print_color $YELLOW "\nConnector: $conn"
        config=$(get_connector_config "$conn")
        
        print_info "Configured tables:"
        tables=$(extract_tables "$config")
        for table in $tables; do
            echo "  - $table"
        done
        
        signal_topic=$(check_signal_topic_config "$config")
        if [ $? -eq 0 ]; then
            print_success "Signal topic configured: $signal_topic"
        else
            print_warning "Signal topic NOT configured - incremental snapshots not available"
        fi
    done
    exit 0
fi

# Select connector if not provided
if [ -z "$CONNECTOR" ]; then
    print_color $YELLOW "\nPlease select a connector:"
    
    # Build connector selection menu
    declare -a CONNECTOR_ARRAY=($DEBEZIUM_CONNECTORS)
    for i in "${!CONNECTOR_ARRAY[@]}"; do
        echo "$((i+1)). ${CONNECTOR_ARRAY[$i]}"
    done
    
    read -p "Enter number: " CONNECTOR_CHOICE
    
    if ! [[ "$CONNECTOR_CHOICE" =~ ^[0-9]+$ ]] || [ "$CONNECTOR_CHOICE" -lt 1 ] || [ "$CONNECTOR_CHOICE" -gt "${#CONNECTOR_ARRAY[@]}" ]; then
        print_error "Invalid selection"
        exit 1
    fi
    
    FULL_CONNECTOR_NAME="${CONNECTOR_ARRAY[$((CONNECTOR_CHOICE-1))]}"
else
    # Use the provided connector name directly
    FULL_CONNECTOR_NAME="$CONNECTOR"
fi

print_success "Selected connector: $FULL_CONNECTOR_NAME"

# Get connector configuration
print_info "Fetching connector configuration..."
CONNECTOR_CONFIG=$(get_connector_config "$FULL_CONNECTOR_NAME")

if [ -z "$CONNECTOR_CONFIG" ] || [ "$CONNECTOR_CONFIG" = "null" ]; then
    print_error "Failed to fetch configuration for connector: $FULL_CONNECTOR_NAME"
    exit 1
fi

# Check if incremental snapshots are enabled
INCREMENTAL_ENABLED=$(echo "$CONNECTOR_CONFIG" | jq -r '.["incremental.snapshot.enabled"] // "false"' 2>/dev/null)

if [ "$INCREMENTAL_ENABLED" != "true" ]; then
    print_warning "Warning: incremental.snapshot.enabled is not set to true for this connector"
    print_warning "Incremental snapshots may not work properly"
    print_info "To enable incremental snapshots, update the connector configuration with:"
    print_info '  "incremental.snapshot.enabled": "true"'
else
    print_success "Incremental snapshots are enabled for this connector"
fi

# Get signal topic configuration
CONFIG_SIGNAL_TOPIC=$(check_signal_topic_config "$CONNECTOR_CONFIG")
if [ $? -ne 0 ]; then
    print_error "Error: Signal topic is not configured for this connector"
    print_warning "To enable incremental snapshots, the connector needs:"
    print_warning "  1. signal.kafka.topic property set"
    print_warning "  2. signal.enabled.channels must include 'kafka'"
    print_warning "  3. signal.kafka.bootstrap.servers and signal.consumer.group.id configured"
    print_info "\nPlease update the connector configuration and try again."
    exit 1
else
    # Use the configured signal topic
    if [ -z "$SIGNAL_TOPIC" ]; then
        SIGNAL_TOPIC="$CONFIG_SIGNAL_TOPIC"
    fi
fi

print_success "Signal topic: $SIGNAL_TOPIC"

# Check if signal topic exists and create if needed
print_info "Verifying signal topic exists..."
if ! create_signal_topic "$POD_NAME" "$SIGNAL_TOPIC" "$DRY_RUN"; then
    print_error "Failed to create signal topic. Cannot proceed with snapshot trigger."
    exit 1
fi

# If only creating topics, exit here
if [ "$CREATE_TOPICS_ONLY" = true ]; then
    print_success "\n✓ Signal topic setup completed!"
    print_info "Signal topic '$SIGNAL_TOPIC' is ready for use."
    print_color $YELLOW "\nYou can now trigger snapshots using:"
    echo "  $0 --env $ENV_FILE -c ${CONNECTOR:-<full-connector-name>} -t <tables>"
    exit 0
fi

# Get topic prefix if not already set
if [ -z "$TOPIC_PREFIX" ]; then
    TOPIC_PREFIX=$(get_topic_prefix "$CONNECTOR_CONFIG")
fi
print_success "Topic prefix: $TOPIC_PREFIX"

# Get available tables
AVAILABLE_TABLES=$(extract_tables "$CONNECTOR_CONFIG")

print_info "Available tables in connector:"
for table in $AVAILABLE_TABLES; do
    echo "  - $table"
done

# Select tables if not provided
if [ -z "$TABLES" ]; then
    print_color $YELLOW "\nEnter comma-separated list of tables to snapshot:"
    print_color $YELLOW "(e.g., public.inventory,public.task)"
    read -p "> " TABLES
fi

if [ -z "$TABLES" ]; then
    print_error "No tables specified"
    exit 1
fi

# Validate tables
print_info "Validating selected tables..."
IFS=',' read -ra TABLE_ARRAY <<< "$TABLES"
VALID_TABLES=()
INVALID_TABLES=()

for table in "${TABLE_ARRAY[@]}"; do
    # Trim whitespace
    table=$(echo "$table" | xargs)
    
    # Check if table exists in connector configuration
    if echo "$AVAILABLE_TABLES" | grep -q "^$table$"; then
        VALID_TABLES+=("$table")
        print_success "  ✓ $table"
    else
        INVALID_TABLES+=("$table")
        print_error "  ✗ $table (not found in connector configuration)"
    fi
done

if [ ${#INVALID_TABLES[@]} -gt 0 ]; then
    print_warning "Warning: Some tables were not found in the connector configuration"
    print_color $YELLOW "Do you want to continue with valid tables only? (y/n)"
    read -p "> " CONTINUE
    
    if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
        exit 1
    fi
fi

if [ ${#VALID_TABLES[@]} -eq 0 ]; then
    print_error "No valid tables to snapshot"
    exit 1
fi

# Build data-collections array
DATA_COLLECTIONS=$(printf '"%s",' "${VALID_TABLES[@]}" | sed 's/,$//')

# Function to get snapshot override for a table
get_snapshot_override() {
    local table=$1
    case "$table" in
        "public.inventory")
            echo "ORDER BY fcm_id"
            ;;
        "public.task"|"public.pd_pick_item"|"public.pd_drop_item"|"public.pd_pick_drop_mapping"|"public.ob_load_item"|"public.inb_receive_item"|"public.inb_qc_item_v2"|"public.inb_palletization_item"|"public.inb_serialization_item"|"public.ob_qa_lineitem")
            echo "ORDER BY id DESC"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Build additional conditions with snapshot overrides
ADDITIONAL_CONDITIONS=""
for table in "${VALID_TABLES[@]}"; do
    if [ -n "$ADDITIONAL_CONDITIONS" ]; then
        ADDITIONAL_CONDITIONS="$ADDITIONAL_CONDITIONS,"
    fi
    
    # Check if table has a snapshot override
    SNAPSHOT_OVERRIDE=$(get_snapshot_override "$table")
    if [ -n "$SNAPSHOT_OVERRIDE" ]; then
        if [ -n "$FILTER" ]; then
            # Combine filter with override
            ADDITIONAL_CONDITIONS="$ADDITIONAL_CONDITIONS{\"data-collection\":\"$table\",\"filter\":\"$FILTER ${SNAPSHOT_OVERRIDE}\"}"
        else
            # Use override only
            ADDITIONAL_CONDITIONS="$ADDITIONAL_CONDITIONS{\"data-collection\":\"$table\",\"filter\":\"${SNAPSHOT_OVERRIDE}\"}"
        fi
        print_info "Using snapshot override for $table: ${SNAPSHOT_OVERRIDE}"
    elif [ -n "$FILTER" ]; then
        # Use filter only
        ADDITIONAL_CONDITIONS="$ADDITIONAL_CONDITIONS{\"data-collection\":\"$table\",\"filter\":\"$FILTER\"}"
    fi
done

# Create signal message
print_info "Preparing incremental snapshot signal..."

if [ -n "$ADDITIONAL_CONDITIONS" ]; then
    SIGNAL_MESSAGE=$(cat <<EOF
{
  "type": "execute-snapshot",
  "data": {
    "data-collections": [$DATA_COLLECTIONS],
    "type": "INCREMENTAL",
    "additional-conditions": [$ADDITIONAL_CONDITIONS]
  }
}
EOF
)
else
    SIGNAL_MESSAGE=$(cat <<EOF
{
  "type": "execute-snapshot",
  "data": {
    "data-collections": [$DATA_COLLECTIONS],
    "type": "INCREMENTAL"
  }
}
EOF
)
fi

print_success "Signal message:"
echo "$SIGNAL_MESSAGE" | jq .

# For Kafka signals, no ID field is needed (IDs are only for database signaling tables)

# Send signal to Kafka topic
if [ "$DRY_RUN" = true ]; then
    print_color $YELLOW "\n[DRY RUN] Would send signal to Kafka topic: $SIGNAL_TOPIC"
    print_color $YELLOW "Key: $FULL_CONNECTOR_NAME (connector name)"
    print_color $YELLOW "Value:"
    echo "$SIGNAL_MESSAGE" | jq .
else
    print_info "Sending signal to Kafka topic: $SIGNAL_TOPIC"
    print_info "Message key (connector name): $FULL_CONNECTOR_NAME"
    print_success "Final signal message:"
    echo "$SIGNAL_MESSAGE" | jq .
    
    # Prepare the message payload for Aiven Kafka REST API
    # Key must match the connector name
    MESSAGE_PAYLOAD=$(jq -n \
        --arg key "$FULL_CONNECTOR_NAME" \
        --argjson value "$SIGNAL_MESSAGE" \
        '{
            records: [{
                key: $key,
                value: $value
            }]
        }')
    
    # Send message using Aiven Kafka REST API from inside the pod
    response=$(execute_curl_in_pod "$POD_NAME" "POST" \
        "${KAFKA_REST_URL}/topics/${SIGNAL_TOPIC}" \
        "$MESSAGE_PAYLOAD" \
        "-H 'Content-Type: application/vnd.kafka.json.v2+json' -H 'Accept: application/vnd.kafka.v2+json'")
    
    # Handle both macOS and Linux versions of head/tail
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS doesn't support negative line counts in head
        total_lines=$(echo "$response" | wc -l)
        body_lines=$((total_lines - 1))
        if [ $body_lines -gt 0 ]; then
            body=$(echo "$response" | head -n $body_lines)
        else
            body=""
        fi
        status=$(echo "$response" | tail -n1)
    else
        body=$(echo "$response" | sed '$d')
        status=$(echo "$response" | tail -n1)
    fi
    
    if [ "$status" = "200" ] || [ "$status" = "201" ] || [ "$status" = "204" ]; then
        print_success "Message sent successfully!"
        
        # Parse response if available
        if [ -n "$body" ]; then
            offset=$(echo "$body" | jq -r '.offsets[0].offset // ""' 2>/dev/null)
            partition=$(echo "$body" | jq -r '.offsets[0].partition // ""' 2>/dev/null)
            if [ -n "$offset" ]; then
                print_info "Message written to partition $partition at offset $offset"
            fi
        fi
        
        print_success "\n✓ Incremental snapshot signal sent successfully!"
        print_color $YELLOW "\nSnapshot has been triggered for the following tables:"
        for table in "${VALID_TABLES[@]}"; do
            echo "  - $table"
        done
        
        print_info "\nMonitoring tips:"
        print_color $YELLOW "1. Check connector status:"
        echo "   curl -s ${CONNECT_REST_URL}/connectors/$FULL_CONNECTOR_NAME/status | jq ."
        
        print_color $YELLOW "\n2. Monitor Kafka topics for snapshot data:"
        for table in "${VALID_TABLES[@]}"; do
            # Topic name preserves dots in table names
            echo "   - ${TOPIC_PREFIX}.${table}"
        done
        
        print_color $YELLOW "\n3. Check connector logs for snapshot progress:"
        echo "   kubectl logs -n $K8S_NAMESPACE -l $K8S_CONNECT_LABEL --tail=100 -f | grep -i snapshot"
        
    else
        print_error "Failed to send signal via Aiven REST API (HTTP $status)"
        if [ -n "$body" ]; then
            echo "Response: $body"
        fi
        exit 1
    fi
fi

print_success "\nScript completed successfully!"