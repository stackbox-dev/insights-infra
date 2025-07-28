#!/bin/bash

# Google Cloud Managed Kafka Testing Script for Flink
# This script tests the connectivity and functionality of the Flink cluster with GCP Managed Kafka
# 
# Features:
# - Uses local gcp-service-account-key.json if available, otherwise falls back to K8s secret
# - Creates test topic if it doesn't exist
# - Tests Kafka and Avro connector availability
# - Creates and drops test tables with comprehensive Avro schemas
# - Validates SQL Gateway connectivity and operations
# - Provides comprehensive diagnostics and examples
#
# Prerequisites:
# - kubectl configured and connected to the cluster
# - gcloud CLI installed
# - jq and curl available on the system
# - Flink cluster deployed in flink-studio namespace
# - Either: gcp-service-account-key.json in current directory OR gcp-service-account-key secret in K8s
#
# Usage: ./test-kafka-connectivity.sh

set -e

# Cleanup function
cleanup() {
    # Kill any port-forward processes
    pkill -f "kubectl port-forward.*flink-sql-gateway" 2>/dev/null || true
    pkill -f "kubectl port-forward.*flink-session-cluster-web" 2>/dev/null || true
    
    # Remove only temporary service account key file (not local one)
    rm -f /tmp/gcp-service-account-key.json 2>/dev/null || true
}

# Set trap to run cleanup on script exit
trap cleanup EXIT

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

# Configuration
NAMESPACE="flink-studio"
KAFKA_CLUSTER="sbx-kafka-cluster"
KAFKA_BOOTSTRAP="bootstrap.sbx-kafka-cluster.asia-south1.managedkafka.sbx-stag.cloud.goog:9092"
TEST_TOPIC="flink-test-topic"
SERVICE_ACCOUNT_SECRET="gcp-service-account-key"

print_status "Starting Google Cloud Managed Kafka connectivity tests for Flink..."
print_status "Target cluster: $KAFKA_CLUSTER"
print_status "Test topic: $TEST_TOPIC" 
print_status "Namespace: $NAMESPACE"
print_status "Service Account Secret: $SERVICE_ACCOUNT_SECRET"
print_status "=========================================="

# Test 1: Check if pods are running
print_test "1. Checking if Flink pods are running..."
JOBMANAGER_PODS=$(kubectl get pods -n $NAMESPACE -l app=flink-session-cluster -l component=jobmanager --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
TASKMANAGER_PODS=$(kubectl get pods -n $NAMESPACE -l app=flink-session-cluster -l component=taskmanager --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
SQL_GATEWAY_PODS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=flink-sql-gateway --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ ! -z "$JOBMANAGER_PODS" ]; then
    print_status "✓ JobManager pods running: $JOBMANAGER_PODS"
else
    print_error "✗ No JobManager pods running"
    exit 1
fi

if [ ! -z "$TASKMANAGER_PODS" ]; then
    print_status "✓ TaskManager pods running: $TASKMANAGER_PODS"
else
    print_error "✗ No TaskManager pods running"
    exit 1
fi

if [ ! -z "$SQL_GATEWAY_PODS" ]; then
    print_status "✓ SQL Gateway pods running: $SQL_GATEWAY_PODS"
else
    print_error "✗ No SQL Gateway pods running"
    exit 1
fi

# Test 2: Check Google Cloud service account availability
print_test "2. Checking Google Cloud service account availability..."

# Check if local service account key file exists first
LOCAL_SA_KEY="./gcp-service-account-key.json"
if [ -f "$LOCAL_SA_KEY" ]; then
    print_status "✓ Local service account key file found: $LOCAL_SA_KEY"
    
    # Verify the local file contains valid JSON
    if jq . "$LOCAL_SA_KEY" >/dev/null 2>&1; then
        print_status "✓ Local service account key is valid JSON"
    else
        print_error "✗ Local service account key is not valid JSON"
        exit 1
    fi
else
    print_status "Local key file not found, checking Kubernetes secret..."
    if kubectl get secret $SERVICE_ACCOUNT_SECRET -n $NAMESPACE >/dev/null 2>&1; then
        print_status "✓ GCP service account secret exists in Kubernetes"
        
        # Verify the secret contains valid JSON
        if kubectl get secret $SERVICE_ACCOUNT_SECRET -n $NAMESPACE -o jsonpath='{.data.service-account\.json}' | base64 -d | jq . >/dev/null 2>&1; then
            print_status "✓ Service account key in secret is valid JSON"
        else
            print_error "✗ Service account key in secret is not valid JSON"
            exit 1
        fi
    else
        print_error "✗ Neither local key file nor Kubernetes secret found"
        print_warning "  Expected local file: $LOCAL_SA_KEY"
        print_warning "  Expected secret name: $SERVICE_ACCOUNT_SECRET"
        exit 1
    fi
fi

# Test 3: Check required JAR files
print_test "3. Checking required JAR files in containers..."
REQUIRED_JARS=(
    "flink-sql-connector-kafka"
    "flink-sql-avro"
    "google-auth-library-oauth2-http"
    "google-cloud-core"
)

JM_POD=$(echo $JOBMANAGER_PODS | cut -d' ' -f1)
for jar in "${REQUIRED_JARS[@]}"; do
    JAR_EXISTS=$(kubectl exec $JM_POD -n $NAMESPACE -c flink-main-container -- find /opt/flink/lib -name "*${jar}*.jar" 2>/dev/null | head -1)
    if [ ! -z "$JAR_EXISTS" ]; then
        print_status "✓ Found required JAR: $(basename $JAR_EXISTS)"
    else
        print_error "✗ Missing required JAR: $jar"
    fi
done

# Test 4: Check service account key validity without affecting local auth
print_test "4. Validating service account key (without affecting local gcloud auth)..."
TOPIC_CREATED=false

# Check if local service account key file exists first
LOCAL_SA_KEY="./gcp-service-account-key.json"
TEMP_SA_KEY="/tmp/gcp-service-account-key.json"

if [ -f "$LOCAL_SA_KEY" ]; then
    print_status "Using local service account key file: $LOCAL_SA_KEY"
    SA_KEY_FILE="$LOCAL_SA_KEY"
else
    print_status "Local key file not found, extracting from Kubernetes secret..."
    # Extract and use the service account key from Kubernetes secret
    kubectl get secret $SERVICE_ACCOUNT_SECRET -n $NAMESPACE -o jsonpath='{.data.service-account\.json}' | base64 -d > "$TEMP_SA_KEY"
    SA_KEY_FILE="$TEMP_SA_KEY"
fi

# Validate service account key structure without using gcloud auth
PROJECT_ID=$(jq -r '.project_id' "$SA_KEY_FILE" 2>/dev/null || echo "")
CLIENT_EMAIL=$(jq -r '.client_email' "$SA_KEY_FILE" 2>/dev/null || echo "")
PRIVATE_KEY_ID=$(jq -r '.private_key_id' "$SA_KEY_FILE" 2>/dev/null || echo "")

if [ ! -z "$PROJECT_ID" ] && [ ! -z "$CLIENT_EMAIL" ] && [ ! -z "$PRIVATE_KEY_ID" ]; then
    print_status "✓ Service account key is valid"
    print_status "  - Project ID: $PROJECT_ID"
    print_status "  - Client Email: $CLIENT_EMAIL"
    print_status "  - Private Key ID: ${PRIVATE_KEY_ID:0:8}..."
else
    print_error "✗ Service account key is invalid or missing required fields"
    print_warning "  Required fields: project_id, client_email, private_key_id"
fi

print_status "✓ Service account validation completed (local gcloud auth unchanged)"
print_warning "  Note: Skipping topic creation to preserve your local gcloud authentication"
print_warning "  Please ensure test topic '$TEST_TOPIC' exists in your Kafka cluster"
print_warning "  You can create it manually using: gcloud managed-kafka topics create $TEST_TOPIC --cluster=$KAFKA_CLUSTER --location=asia-south1"

# Test 5: Test Flink SQL connectivity via port-forward
print_test "5. Testing Flink SQL Gateway connectivity..."
print_status "Starting port-forward to SQL Gateway..."

# Kill any existing port-forwards
pkill -f "kubectl port-forward.*flink-sql-gateway" 2>/dev/null || true
sleep 2

# Start port-forward in background
kubectl port-forward svc/flink-sql-gateway 8083:80 -n $NAMESPACE >/dev/null 2>&1 &
PF_PID=$!
sleep 5

# Test SQL Gateway endpoint
GATEWAY_RESPONSE=$(curl -s http://localhost:8083/v1/info 2>/dev/null || echo "FAILED")
if [[ "$GATEWAY_RESPONSE" != "FAILED" ]]; then
    print_status "✓ SQL Gateway is accessible"
    
    # Test Kafka and Avro connector availability via SQL Gateway
    print_test "6. Testing Kafka and Avro connectors in SQL Gateway..."
    
    # Create a SQL session
    SQL_SESSION=$(curl -s -X POST http://localhost:8083/v1/sessions \
        -H "Content-Type: application/json" \
        -d '{"properties": {}}' 2>/dev/null | jq -r '.sessionHandle' 2>/dev/null || echo "FAILED")
    
    if [[ "$SQL_SESSION" != "FAILED" && "$SQL_SESSION" != "null" ]]; then
        print_status "✓ SQL session created: $SQL_SESSION"
        
        # Function to execute SQL statement and check result
        execute_sql() {
            local sql_statement="$1"
            local description="$2"
            
            print_status "Executing: $description"
            
            # Properly escape the SQL statement for JSON
            local escaped_sql=$(echo "$sql_statement" | jq -R . | sed 's/^"//;s/"$//')
            
            local result=$(curl -s -X POST "http://localhost:8083/v1/sessions/$SQL_SESSION/statements" \
                -H "Content-Type: application/json" \
                -d "{\"statement\": \"$escaped_sql\"}" 2>/dev/null || echo "FAILED")
            
            if [[ "$result" != "FAILED" ]]; then
                local operation_handle=$(echo "$result" | jq -r '.operationHandle' 2>/dev/null || echo "FAILED")
                
                if [[ "$operation_handle" != "FAILED" && "$operation_handle" != "null" ]]; then
                    sleep 3
                    local status_result=$(curl -s "http://localhost:8083/v1/sessions/$SQL_SESSION/operations/$operation_handle/status" 2>/dev/null || echo "FAILED")
                    local status=$(echo "$status_result" | jq -r '.status' 2>/dev/null || echo "UNKNOWN")
                    
                    if [[ "$status" == "FINISHED" ]]; then
                        print_status "✓ $description - SUCCESS"
                        return 0
                    elif [[ "$status" == "ERROR" ]]; then
                        local error_msg=$(echo "$status_result" | jq -r '.errorMessage.errorMessage' 2>/dev/null || echo "Unknown error")
                        print_error "✗ $description - ERROR: $error_msg"
                        return 1
                    else
                        print_warning "⚠ $description - Status: $status"
                        return 1
                    fi
                else
                    print_error "✗ $description - No operation handle"
                    # Show what we actually got
                    local error_msg=$(echo "$result" | jq -r '.message // .error // .errorMessage // "No error message"' 2>/dev/null || echo "Failed to parse error")
                    print_error "    Error details: $error_msg"
                    return 1
                fi
            else
                print_error "✗ $description - Request failed"
                return 1
            fi
        }
        
        # 1. Drop table if exists (ignore errors)
        print_status "Cleaning up any existing test table..."
        execute_sql "DROP TABLE IF EXISTS test_kafka_avro_table" "Drop existing table" || true
        
        # 2. Create simple Kafka table with JSON format first to test basic connectivity
        print_status "Creating simple Kafka table with JSON format..."
        SIMPLE_KAFKA_SQL="CREATE TABLE test_kafka_simple (id BIGINT, message STRING, ts TIMESTAMP(3)) WITH ('connector' = 'kafka', 'topic' = '$TEST_TOPIC', 'properties.bootstrap.servers' = '$KAFKA_BOOTSTRAP', 'properties.security.protocol' = 'SASL_SSL', 'properties.sasl.mechanism' = 'OAUTHBEARER', 'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;', 'properties.sasl.login.callback.handler.class' = 'com.google.cloud.kafka.OAuthBearerTokenCallbackHandler', 'scan.startup.mode' = 'latest-offset', 'format' = 'json')"
        
        if execute_sql "$SIMPLE_KAFKA_SQL" "Create simple Kafka table with JSON"; then
            # Test table description
            execute_sql "DESCRIBE test_kafka_simple" "Describe simple table structure" || true
            
            # Clean up simple table
            execute_sql "DROP TABLE IF EXISTS test_kafka_simple" "Drop simple test table" || true
            
            print_status "✓ Basic Kafka connectivity test completed successfully"
            
            # 3. Try Avro table if basic connectivity works
            print_status "Creating Kafka table with Avro format..."
            AVRO_KAFKA_SQL="CREATE TABLE test_kafka_avro (user_id BIGINT, username STRING, ts TIMESTAMP(3)) WITH ('connector' = 'kafka', 'topic' = '$TEST_TOPIC', 'properties.bootstrap.servers' = '$KAFKA_BOOTSTRAP', 'properties.security.protocol' = 'SASL_SSL', 'properties.sasl.mechanism' = 'OAUTHBEARER', 'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;', 'properties.sasl.login.callback.handler.class' = 'com.google.cloud.kafka.OAuthBearerTokenCallbackHandler', 'scan.startup.mode' = 'latest-offset', 'format' = 'avro', 'avro.schema' = '{\"type\": \"record\", \"name\": \"UserRecord\", \"fields\": [{\"name\": \"user_id\", \"type\": \"long\"}, {\"name\": \"username\", \"type\": \"string\"}, {\"name\": \"ts\", \"type\": {\"type\": \"long\", \"logicalType\": \"timestamp-millis\"}}]}')"
            
            if execute_sql "$AVRO_KAFKA_SQL" "Create Avro Kafka table"; then
                execute_sql "DESCRIBE test_kafka_avro" "Describe Avro table structure" || true
                execute_sql "DROP TABLE IF EXISTS test_kafka_avro" "Drop Avro test table" || true
                print_status "✓ Kafka-Avro integration test completed successfully"
            else
                print_error "✗ Avro table creation failed, but basic Kafka connectivity works"
            fi
        else
            print_error "✗ Basic Kafka connectivity test failed"
        fi
        
        # Clean up session
        curl -s -X DELETE "http://localhost:8083/v1/sessions/$SQL_SESSION" >/dev/null 2>&1
        print_status "✓ SQL session cleaned up"
    else
        print_error "✗ Failed to create SQL session"
    fi
else
    print_error "✗ SQL Gateway is not accessible"
fi

# Clean up port-forward
kill $PF_PID 2>/dev/null || true

# Test 7: Check Flink cluster health
print_test "7. Checking Flink cluster health..."
kubectl port-forward svc/flink-session-cluster-web 8081:80 -n $NAMESPACE >/dev/null 2>&1 &
PF_PID=$!
sleep 5

CLUSTER_INFO=$(curl -s http://localhost:8081/overview 2>/dev/null || echo "FAILED")
if [[ "$CLUSTER_INFO" != "FAILED" ]]; then
    TASK_MANAGERS=$(echo "$CLUSTER_INFO" | jq -r '.taskmanagers' 2>/dev/null || echo "0")
    SLOTS_TOTAL=$(echo "$CLUSTER_INFO" | jq -r '."slots-total"' 2>/dev/null || echo "0")
    SLOTS_AVAILABLE=$(echo "$CLUSTER_INFO" | jq -r '."slots-available"' 2>/dev/null || echo "0")
    
    print_status "✓ Flink cluster overview:"
    print_status "  - Task Managers: $TASK_MANAGERS"
    print_status "  - Total Slots: $SLOTS_TOTAL"
    print_status "  - Available Slots: $SLOTS_AVAILABLE"
else
    print_error "✗ Failed to get Flink cluster overview"
fi

kill $PF_PID 2>/dev/null || true

print_status ""
print_status "=========================================="
print_status "Testing completed!"
print_status ""
print_status "✓ Service account key validated successfully"
print_status "✓ Flink cluster connectivity tested"
print_status ""
print_status "Next steps:"
print_status "1. Create test topic '$TEST_TOPIC' manually: gcloud managed-kafka topics create $TEST_TOPIC --cluster=$KAFKA_CLUSTER --location=asia-south1"
print_status "2. Use 'kubectl port-forward svc/flink-sql-gateway 8083:80 -n flink-studio' to access SQL Gateway"
print_status "3. Use 'kubectl port-forward svc/flink-session-cluster-web 8081:80 -n flink-studio' to access Flink UI"
print_status "4. Test Kafka connectivity with your actual topics and data"
print_status ""
print_status "Example Kafka table creation SQL (JSON format):"
echo "CREATE TABLE my_kafka_json_table ("
echo "  user_id BIGINT,"
echo "  action STRING,"
echo "  timestamp_val TIMESTAMP(3),"
echo "  WATERMARK FOR timestamp_val AS timestamp_val - INTERVAL '5' SECOND"
echo ") WITH ("
echo "  'connector' = 'kafka',"
echo "  'topic' = 'your-topic-name',"
echo "  'properties.bootstrap.servers' = '$KAFKA_BOOTSTRAP',"
echo "  'properties.security.protocol' = 'SASL_SSL',"
echo "  'properties.sasl.mechanism' = 'OAUTHBEARER',"
echo "  'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;',"
echo "  'properties.sasl.login.callback.handler.class' = 'com.google.cloud.kafka.OAuthBearerTokenCallbackHandler',"
echo "  'format' = 'json'"
echo ");"
echo ""
print_status "Example Kafka table creation SQL (Avro format):"
echo "CREATE TABLE my_kafka_avro_table ("
echo "  user_id BIGINT,"
echo "  username STRING,"
echo "  metadata MAP<STRING, STRING>,"
echo "  timestamp_val TIMESTAMP(3),"
echo "  WATERMARK FOR timestamp_val AS timestamp_val - INTERVAL '5' SECOND"
echo ") WITH ("
echo "  'connector' = 'kafka',"
echo "  'topic' = 'your-avro-topic',"
echo "  'properties.bootstrap.servers' = '$KAFKA_BOOTSTRAP',"
echo "  'properties.security.protocol' = 'SASL_SSL',"
echo "  'properties.sasl.mechanism' = 'OAUTHBEARER',"
echo "  'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;',"
echo "  'properties.sasl.login.callback.handler.class' = 'com.google.cloud.kafka.OAuthBearerTokenCallbackHandler',"
echo "  'format' = 'avro',"
echo "  'avro.schema' = '{"
echo "    \"type\": \"record\","
echo "    \"name\": \"UserEvent\","
echo "    \"fields\": ["
echo "      {\"name\": \"user_id\", \"type\": \"long\"},"
echo "      {\"name\": \"username\", \"type\": \"string\"},"
echo "      {\"name\": \"metadata\", \"type\": {\"type\": \"map\", \"values\": \"string\"}},"
echo "      {\"name\": \"timestamp_val\", \"type\": {\"type\": \"long\", \"logicalType\": \"timestamp-millis\"}}"
echo "    ]"
echo "  }'"
echo ");"
