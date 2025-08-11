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

Create Debezium signal topics for incremental snapshots

REQUIRED:
    --env <file>       Environment configuration file (e.g., .sbx-uat.env)

OPTIONS:
    --dry-run          Show what topics would be created without actually creating them
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

print_color $BLUE "=================================="
print_color $BLUE "  Debezium Signal Topics Creation "
print_color $BLUE "=================================="
echo ""

# Find a pod to execute commands from
print_info "Finding Kafka Connect pod..."
CONNECT_POD=$(get_connect_pod)
if [ $? -ne 0 ]; then
    exit 1
fi

print_success "Using pod: $CONNECT_POD"

# Signal topics to create from environment configuration
SIGNAL_TOPICS=(
    "$WMS_SIGNAL_TOPIC"
    "$ENCARTA_SIGNAL_TOPIC"
    "$BACKBONE_SIGNAL_TOPIC"
)

# Topic configuration
# Using 1 partition since signal topics don't need high throughput
# Using infinite retention to preserve signal history

print_color $YELLOW "Will create the following signal topics:"
for topic in "${SIGNAL_TOPICS[@]}"; do
    echo "  - $topic"
done
echo ""

if [ "$DRY_RUN" = true ]; then
    print_color $YELLOW "[DRY RUN] Would create the above topics with configuration:"
    echo "  - Partitions: 1"
    echo "  - Replication Factor: 3"
    echo "  - Retention: Infinite"
    echo "  - Compression: lz4"
    echo "  - Min In-Sync Replicas: 2"
    exit 0
fi

read -p "Do you want to proceed? (y/n): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    print_warning "Operation cancelled by user"
    exit 0
fi

echo ""
print_info "Creating Debezium signal topics..."
echo ""

# Create each signal topic using Aiven Kafka Admin REST API
for topic in "${SIGNAL_TOPICS[@]}"; do
    print_color $YELLOW "Creating topic: $topic"
    
    # Check if topic already exists
    check_response=$(execute_curl_in_pod "$CONNECT_POD" "GET" \
        "${KAFKA_REST_URL}/admin/topics/${topic}" \
        "" \
        "-H 'Accept: application/json'")
    
    check_status=$(echo "$check_response" | tail -n1)
    
    if [ "$check_status" = "200" ]; then
        print_warning "  ⚠️  Topic already exists"
    else
        # Create the topic using Aiven Admin API
        create_payload=$(cat <<EOF
{
    "topic": "${topic}",
    "partitions": 1,
    "replication": 3,
    "config": {
        "retention.ms": "-1",
        "compression.type": "lz4",
        "min.insync.replicas": "2"
    }
}
EOF
)
        
        create_response=$(execute_curl_in_pod "$CONNECT_POD" "POST" \
            "${KAFKA_REST_URL}/admin/topics" \
            "$create_payload" \
            "-H 'Content-Type: application/json' -H 'Accept: application/json'")
        
        create_status=$(echo "$create_response" | tail -n1)
        
        if [ "$create_status" = "200" ] || [ "$create_status" = "201" ]; then
            print_success "  ✅ Topic created successfully"
        else
            # Try alternative: Using kafka-topics command inside the pod
            print_warning "  Trying alternative method..."
            
            create_cmd="kafka-topics --create \
                --bootstrap-server $KAFKA_BOOTSTRAP_SERVERS \
                --topic ${topic} \
                --partitions 1 \
                --replication-factor 3 \
                --config retention.ms=-1 \
                --config compression.type=lz4 \
                --config min.insync.replicas=2"
            
            if execute_kafka_command "$CONNECT_POD" "$create_cmd"; then
                print_success "  ✅ Topic created successfully"
            else
                print_error "  ❌ Failed to create topic"
            fi
        fi
    fi
done

echo ""
print_info "Verifying created topics..."
echo ""

# Verify the topics were created using kafka-topics --list
existing_topics=$(execute_kafka_command "$CONNECT_POD" "kafka-topics --list")

for topic in "${SIGNAL_TOPICS[@]}"; do
    if echo "$existing_topics" | grep -q "^$topic$"; then
        print_success "✅ $topic - Verified"
    else
        print_error "❌ $topic - Not found"
    fi
done

echo ""
print_success "Signal topics setup completed!"
echo ""
print_color $YELLOW "Next steps:"
print_color $YELLOW "1. Update the connectors with their respective scripts:"
echo "   ./wms-debezium-postgres.sh --env $ENV_FILE"
echo "   ./encarta-debezium-postgres.sh --env $ENV_FILE"
echo "   ./backbone-debezium-postgres.sh --env $ENV_FILE"
echo ""
print_color $YELLOW "2. Once connectors are updated, trigger snapshots using:"
echo "   ./trigger-snapshots.sh --env $ENV_FILE -c <connector> -t <tables>"