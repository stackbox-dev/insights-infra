#!/bin/bash

# Common functions and utilities for Kafka/Debezium connector scripts

# ====================
# Color codes for output
# ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ====================
# Output Functions
# ====================
print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

print_error() {
    print_color $RED "❌ ERROR: $@" >&2
}

print_warning() {
    print_color $YELLOW "⚠️  WARNING: $@"
}

print_success() {
    print_color $GREEN "✅ SUCCESS: $@"
}

print_info() {
    print_color $BLUE "ℹ️  INFO: $@"
}

print_debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        print_color $CYAN "🔍 DEBUG: $@"
    fi
}

# ====================
# Environment File Loading
# ====================
load_env_file() {
    local env_file=$1
    
    if [ -z "$env_file" ]; then
        print_error "Environment file not specified. Use --env <file> parameter"
        return 1
    fi
    
    if [ ! -f "$env_file" ]; then
        print_error "Environment file not found: $env_file"
        return 1
    fi
    
    print_info "Loading environment from: $env_file"
    
    # Load the environment file
    set -a  # automatically export all variables
    source "$env_file"
    set +a  # disable automatic export
    
    # Validate required variables
    validate_env_vars
    return $?
}

# ====================
# Environment Validation
# ====================
validate_env_vars() {
    local required_vars=(
        "K8S_NAMESPACE"
        "K8S_CONNECT_LABEL"
        "KAFKA_BOOTSTRAP_SERVERS"
        "KAFKA_REST_URL"
        "SCHEMA_REGISTRY_URL"
        "K8S_AIVEN_SECRET"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        print_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        return 1
    fi
    
    print_debug "All required environment variables are set"
    return 0
}

# ====================
# Kubernetes Context Check
# ====================
check_kubernetes_context() {
    local current_context
    current_context=$(kubectl config current-context 2>/dev/null)
    
    if [ -z "$current_context" ]; then
        print_error "No Kubernetes context is currently active"
        print_info "Please run: kubectl config use-context <context-name>"
        return 1
    fi
    
    print_info "Current Kubernetes context: ${current_context}"
    
    # Get cluster info
    local cluster_info
    cluster_info=$(kubectl cluster-info 2>/dev/null | head -n1)
    print_info "Cluster: ${cluster_info}"
    
    # Prompt for confirmation
    echo ""
    read -p "Do you want to continue with this context? (y/n): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_warning "Operation cancelled by user"
        return 1
    fi
    
    return 0
}

# ====================
# Kubernetes Functions
# ====================
get_connect_pod() {
    local pod_name
    pod_name=$(kubectl get pods -n "$K8S_NAMESPACE" -l "$K8S_CONNECT_LABEL" -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
    
    if [ -z "$pod_name" ]; then
        print_error "No Connect pod found with label: $K8S_CONNECT_LABEL in namespace: $K8S_NAMESPACE"
        return 1
    fi
    
    echo "$pod_name"
    return 0
}

fetch_kubernetes_credentials() {
    # Fetch Aiven credentials
    export CLUSTER_USER_NAME=$(kubectl get secret "$K8S_AIVEN_SECRET" -n "$K8S_NAMESPACE" -o jsonpath='{.data.username}' | base64 --decode 2>/dev/null)
    export CLUSTER_PASSWORD=$(kubectl get secret "$K8S_AIVEN_SECRET" -n "$K8S_NAMESPACE" -o jsonpath='{.data.password}' | base64 --decode 2>/dev/null)
    export SCHEMA_REGISTRY_AUTH=$(kubectl get secret "$K8S_AIVEN_SECRET" -n "$K8S_NAMESPACE" -o jsonpath='{.data.userinfo}' | base64 --decode 2>/dev/null)
    
    if [ -z "$CLUSTER_USER_NAME" ] || [ -z "$CLUSTER_PASSWORD" ]; then
        print_error "Failed to fetch Kafka credentials from secret: $K8S_AIVEN_SECRET"
        return 1
    fi
    
    print_debug "Successfully fetched Kubernetes credentials"
    return 0
}

fetch_db_password() {
    local secret_name=$1
    
    if [ -z "$secret_name" ]; then
        print_error "Database password secret name not provided"
        return 1
    fi
    
    local password
    password=$(kubectl get secret "$secret_name" -n "$K8S_NAMESPACE" -o jsonpath='{.data.password}' | base64 --decode 2>/dev/null)
    
    if [ -z "$password" ]; then
        print_error "Failed to fetch database password from secret: $secret_name"
        return 1
    fi
    
    echo "$password"
    return 0
}

# ====================
# Port Forwarding Functions
# ====================
start_port_forward() {
    local pod_name=$1
    local local_port=${2:-$CONNECT_LOCAL_PORT}
    local remote_port=${3:-$CONNECT_REMOTE_PORT}
    
    # Kill any existing port forwarding on the same local port
    print_debug "Checking for existing port forwarding on port $local_port"
    local existing_pids=$(lsof -ti:$local_port 2>/dev/null)
    if [ -n "$existing_pids" ]; then
        print_warning "Found existing process(es) on port $local_port, killing them: $existing_pids" >&2
        echo "$existing_pids" | xargs kill -9 2>/dev/null || true
        sleep 1
    fi
    
    print_info "Starting port forwarding from localhost:$local_port to $pod_name:$remote_port" >&2
    
    kubectl port-forward -n "$K8S_NAMESPACE" pod/"$pod_name" "$local_port":"$remote_port" > /dev/null 2>&1 &
    local port_forward_pid=$!
    
    # Wait for port forwarding to be ready
    sleep 3
    
    # Check if port forwarding started successfully
    if ! ps -p $port_forward_pid > /dev/null; then
        print_error "Port forwarding failed to start"
        return 1
    fi
    
    echo "$port_forward_pid"
    return 0
}

stop_port_forward() {
    local pid=$1
    
    if [ -n "$pid" ] && ps -p "$pid" > /dev/null 2>&1; then
        print_info "Stopping port forwarding (PID: $pid)"
        kill "$pid" 2>/dev/null || true
    fi
}

# ====================
# Common Script Setup
# ====================
common_setup() {
    local env_file=""
    local skip_context_check=false
    
    # Parse common arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --env)
                env_file="$2"
                shift 2
                ;;
            --skip-context-check)
                skip_context_check=true
                shift
                ;;
            *)
                # Return remaining arguments for script-specific parsing
                echo "$@"
                break
                ;;
        esac
    done
    
    # Load environment file
    if ! load_env_file "$env_file"; then
        exit 1
    fi
    
    # Check Kubernetes context
    if [ "$skip_context_check" = false ]; then
        if ! check_kubernetes_context; then
            exit 1
        fi
    fi
    
    # Fetch credentials
    if ! fetch_kubernetes_credentials; then
        exit 1
    fi
    
    return 0
}

# ====================
# Cleanup Function
# ====================
cleanup() {
    local port_forward_pid=$1
    
    if [ -n "$port_forward_pid" ]; then
        stop_port_forward "$port_forward_pid"
    fi
    
    print_debug "Cleanup completed"
}

# ====================
# Signal Handling
# ====================
setup_signal_handlers() {
    local cleanup_function=$1
    
    trap "$cleanup_function" EXIT INT TERM
}

# ====================
# Kafka Admin Functions
# ====================
execute_kafka_command() {
    local pod_name=$1
    local command=$2
    
    # Execute kafka command using the pod's existing truststore
    kubectl exec -n "$K8S_NAMESPACE" "$pod_name" -- bash -c '
        # The pod already has the truststore at /etc/kafka/secrets/kafka.truststore.jks
        # and the password in the file /etc/kafka/secrets/truststore-password
        TRUSTSTORE_PASSWORD=$(cat /etc/kafka/secrets/truststore-password)
        
        '"$command"' \
            --bootstrap-server '"${KAFKA_BOOTSTRAP_SERVERS}"' \
            --command-config <(cat <<EOF
security.protocol=SASL_SSL
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="${CLUSTER_USER_NAME}" password="${CLUSTER_PASSWORD}";
ssl.truststore.location=/etc/kafka/secrets/kafka.truststore.jks
ssl.truststore.password=${TRUSTSTORE_PASSWORD}
EOF
)
    '
}

# ====================
# Signal Topic Functions
# ====================
check_topic_exists() {
    local pod_name=$1
    local topic_name=$2
    
    # Check if topic exists by listing topics and checking for exact match
    local topic_list
    topic_list=$(execute_kafka_command "$pod_name" "kafka-topics --list" 2>/dev/null)
    
    if echo "$topic_list" | grep -q "^${topic_name}$"; then
        return 0  # Topic exists
    else
        return 1  # Topic does not exist
    fi
}

create_signal_topic() {
    local pod_name=$1
    local topic_name=$2
    local dry_run=${3:-false}
    
    print_info "Checking if signal topic exists: $topic_name"
    
    if check_topic_exists "$pod_name" "$topic_name"; then
        print_success "Signal topic already exists: $topic_name"
        return 0
    fi
    
    print_warning "Signal topic does not exist: $topic_name"
    
    if [ "$dry_run" = true ]; then
        print_color $YELLOW "[DRY RUN] Would create signal topic: $topic_name"
        print_color $YELLOW "  - Partitions: 1"
        print_color $YELLOW "  - Replication Factor: 3"
        print_color $YELLOW "  - Retention: Infinite"
        print_color $YELLOW "  - Compression: lz4"
        print_color $YELLOW "  - Min In-Sync Replicas: 2"
        return 0
    fi
    
    print_color $YELLOW "Creating signal topic: $topic_name"
    print_info "Do you want to create this signal topic? (y/n)"
    read -p "> " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_error "Signal topic creation cancelled by user"
        return 1
    fi
    
    # Create the topic using kafka-topics command
    create_cmd="kafka-topics --create \
        --topic ${topic_name} \
        --partitions 1 \
        --replication-factor 3 \
        --config retention.ms=-1 \
        --config compression.type=lz4 \
        --config min.insync.replicas=2"
    
    if execute_kafka_command "$pod_name" "$create_cmd"; then
        print_success "Signal topic created successfully: $topic_name"
        return 0
    else
        print_error "Failed to create signal topic: $topic_name"
        return 1
    fi
}

# ====================
# HTTP Request Functions
# ====================
execute_curl_in_pod() {
    local pod_name=$1
    local method=$2
    local url=$3
    local data=$4
    local additional_headers=$5
    
    local curl_cmd="curl -s -w '\\n%{http_code}' -X $method '$url' -u '${CLUSTER_USER_NAME}:${CLUSTER_PASSWORD}'"
    
    if [ -n "$additional_headers" ]; then
        curl_cmd="$curl_cmd $additional_headers"
    fi
    
    if [ -n "$data" ]; then
        curl_cmd="$curl_cmd -d '$data'"
    fi
    
    kubectl exec -n "$K8S_NAMESPACE" "$pod_name" -- bash -c "$curl_cmd" 2>/dev/null
}

# ====================
# Validation Functions
# ====================
validate_connector_name() {
    local connector=$1
    local valid_connectors=("wms" "encarta" "backbone" "oms")
    
    for valid in "${valid_connectors[@]}"; do
        if [ "$connector" = "$valid" ]; then
            return 0
        fi
    done
    
    print_error "Invalid connector name: $connector"
    print_info "Valid options: ${valid_connectors[*]}"
    return 1
}

# Export common variables for scripts that source this file
export -f print_color print_error print_warning print_success print_info print_debug
export -f load_env_file validate_env_vars check_kubernetes_context
export -f get_connect_pod fetch_kubernetes_credentials fetch_db_password
export -f start_port_forward stop_port_forward
export -f common_setup cleanup setup_signal_handlers
export -f execute_kafka_command execute_curl_in_pod
export -f check_topic_exists create_signal_topic
export -f validate_connector_name