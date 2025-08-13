#!/bin/bash

set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "${SCRIPT_DIR}/common.sh"

# Parse arguments
ENV_FILE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            ENV_FILE="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Load environment
if ! load_env_file "$ENV_FILE"; then
    exit 1
fi

if ! fetch_kubernetes_credentials; then
    exit 1
fi

# Find a pod
print_info "Finding Kafka Connect pod..."
CONNECT_POD=$(get_connect_pod)
if [ $? -ne 0 ]; then
    exit 1
fi

print_success "Using pod: $CONNECT_POD"

# Test Schema Registry connectivity
print_info "Testing Schema Registry connectivity..."
print_info "URL: ${SCHEMA_REGISTRY_URL}"
print_info "Auth: ${CLUSTER_USER_NAME}:***"

# First, test basic connectivity
print_info "\n1. Testing basic connectivity..."
kubectl exec -n "$K8S_NAMESPACE" "$CONNECT_POD" -- bash -c "
    curl -v -X GET '${SCHEMA_REGISTRY_URL}' \
        -u '${CLUSTER_USER_NAME}:${CLUSTER_PASSWORD}' \
        2>&1 | head -20
"

# Test /subjects endpoint
print_info "\n2. Testing /subjects endpoint..."
response=$(kubectl exec -n "$K8S_NAMESPACE" "$CONNECT_POD" -- bash -c "
    curl -s -w '\nHTTP_CODE:%{http_code}' -X GET '${SCHEMA_REGISTRY_URL}/subjects' \
        -u '${CLUSTER_USER_NAME}:${CLUSTER_PASSWORD}' \
        -H 'Accept: application/vnd.schemaregistry.v1+json' \
        2>&1
")

echo "Full response:"
echo "$response"

# Extract HTTP code
http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
body=$(echo "$response" | sed '/HTTP_CODE:/d')

print_info "\nHTTP Status Code: $http_code"
print_info "Response Body:"
echo "$body" | jq . 2>/dev/null || echo "$body"

# If we got schemas, try to delete one
if [ "$http_code" = "200" ]; then
    schemas=$(echo "$body" | jq -r '.[]' 2>/dev/null | head -5)
    if [ -n "$schemas" ]; then
        first_schema=$(echo "$schemas" | head -1)
        print_info "\nTrying to delete schema: $first_schema"
        
        delete_response=$(kubectl exec -n "$K8S_NAMESPACE" "$CONNECT_POD" -- bash -c "
            curl -v -w '\nHTTP_CODE:%{http_code}' -X DELETE '${SCHEMA_REGISTRY_URL}/subjects/${first_schema}?permanent=true' \
                -u '${CLUSTER_USER_NAME}:${CLUSTER_PASSWORD}' \
                -H 'Accept: application/vnd.schemaregistry.v1+json' \
                2>&1
        ")
        
        echo "Delete response:"
        echo "$delete_response"
    fi
fi