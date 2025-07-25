#!/bin/bash

# Google Cloud Managed Kafka Testing Script for Flink
# This script tests the connectivity and functionality of the Flink cluster with GCP Managed Kafka

set -e

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

print_status "Starting Google Cloud Managed Kafka connectivity tests for Flink..."
print_status "=========================================="

# Test 1: Check if pods are running
print_test "1. Checking if Flink pods are running..."
JOBMANAGER_PODS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=flink-session-cluster -l component=jobmanager --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
TASKMANAGER_PODS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=flink-session-cluster -l component=taskmanager --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
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

# Test 2: Check Google Cloud service account secret
print_test "2. Checking Google Cloud service account secret..."
if kubectl get secret gcp-service-account-key -n $NAMESPACE >/dev/null 2>&1; then
    print_status "✓ GCP service account secret exists"
    
    # Verify the secret contains valid JSON
    if kubectl get secret gcp-service-account-key -n $NAMESPACE -o jsonpath='{.data.service-account\.json}' | base64 -d | jq . >/dev/null 2>&1; then
        print_status "✓ Service account key is valid JSON"
    else
        print_error "✗ Service account key is not valid JSON"
    fi
else
    print_error "✗ GCP service account secret not found"
    exit 1
fi

# Test 3: Check required JAR files
print_test "3. Checking required JAR files in containers..."
REQUIRED_JARS=(
    "flink-sql-connector-kafka"
    "managedkafka-client"
    "google-auth-library-oauth2-http"
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

# Test 4: Create test topic (requires gcloud CLI and proper permissions)
print_test "4. Creating test topic in Google Cloud Managed Kafka..."
if command -v gcloud &> /dev/null; then
    # Check if topic already exists
    TOPIC_EXISTS=$(gcloud managed-kafka topics list --cluster=$KAFKA_CLUSTER --location=asia-south1 --format="value(name)" --filter="name:$TEST_TOPIC" 2>/dev/null || echo "")
    
    if [ -z "$TOPIC_EXISTS" ]; then
        print_status "Creating test topic: $TEST_TOPIC"
        if gcloud managed-kafka topics create $TEST_TOPIC \
            --cluster=$KAFKA_CLUSTER \
            --location=asia-south1 \
            --partitions=3 \
            --replication-factor=3 2>/dev/null; then
            print_status "✓ Test topic created successfully"
        else
            print_warning "⚠ Failed to create test topic (check permissions)"
        fi
    else
        print_status "✓ Test topic already exists"
    fi
else
    print_warning "⚠ gcloud CLI not available, skipping topic creation"
fi

# Test 5: Test Flink SQL connectivity via port-forward
print_test "5. Testing Flink SQL Gateway connectivity..."
print_status "Starting port-forward to SQL Gateway..."

# Kill any existing port-forwards
pkill -f "kubectl port-forward.*flink-sql-gateway" 2>/dev/null || true
sleep 2

# Start port-forward in background
kubectl port-forward svc/flink-sql-gateway 8083:8083 -n $NAMESPACE >/dev/null 2>&1 &
PF_PID=$!
sleep 5

# Test SQL Gateway endpoint
GATEWAY_RESPONSE=$(curl -s http://localhost:8083/v1/info 2>/dev/null || echo "FAILED")
if [[ "$GATEWAY_RESPONSE" != "FAILED" ]]; then
    print_status "✓ SQL Gateway is accessible"
    
    # Test Kafka connector availability via SQL Gateway
    print_test "6. Testing Kafka connector in SQL Gateway..."
    
    # Create a simple SQL statement to test Kafka connectivity
    SQL_SESSION=$(curl -s -X POST http://localhost:8083/v1/sessions \
        -H "Content-Type: application/json" \
        -d '{"properties": {}}' 2>/dev/null | jq -r '.sessionHandle' 2>/dev/null || echo "FAILED")
    
    if [[ "$SQL_SESSION" != "FAILED" && "$SQL_SESSION" != "null" ]]; then
        print_status "✓ SQL session created: $SQL_SESSION"
        
        # Test Kafka table creation
        KAFKA_SQL="CREATE TABLE test_kafka_table (
            id BIGINT,
            message STRING,
            ts TIMESTAMP(3),
            WATERMARK FOR ts AS ts - INTERVAL '5' SECOND
        ) WITH (
            'connector' = 'kafka',
            'topic' = '$TEST_TOPIC',
            'properties.bootstrap.servers' = '$KAFKA_BOOTSTRAP',
            'properties.security.protocol' = 'SASL_SSL',
            'properties.sasl.mechanism' = 'OAUTHBEARER',
            'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;',
            'properties.sasl.login.callback.handler.class' = 'com.google.cloud.kafka.OAuthBearerTokenCallbackHandler',
            'scan.startup.mode' = 'latest-offset',
            'format' = 'json'
        )"
        
        KAFKA_TABLE_RESULT=$(curl -s -X POST "http://localhost:8083/v1/sessions/$SQL_SESSION/statements" \
            -H "Content-Type: application/json" \
            -d "{\"statement\": \"$KAFKA_SQL\"}" 2>/dev/null || echo "FAILED")
        
        if [[ "$KAFKA_TABLE_RESULT" != "FAILED" ]]; then
            print_status "✓ Kafka table creation statement executed"
            
            # Check statement status
            OPERATION_HANDLE=$(echo "$KAFKA_TABLE_RESULT" | jq -r '.operationHandle' 2>/dev/null || echo "FAILED")
            if [[ "$OPERATION_HANDLE" != "FAILED" && "$OPERATION_HANDLE" != "null" ]]; then
                sleep 2
                STATUS_RESULT=$(curl -s "http://localhost:8083/v1/sessions/$SQL_SESSION/operations/$OPERATION_HANDLE/status" 2>/dev/null || echo "FAILED")
                STATUS=$(echo "$STATUS_RESULT" | jq -r '.status' 2>/dev/null || echo "UNKNOWN")
                print_status "✓ Statement status: $STATUS"
            fi
        else
            print_error "✗ Failed to execute Kafka table creation"
        fi
        
        # Clean up session
        curl -s -X DELETE "http://localhost:8083/v1/sessions/$SQL_SESSION" >/dev/null 2>&1
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
kubectl port-forward svc/flink-session-cluster-rest 8081:8081 -n $NAMESPACE >/dev/null 2>&1 &
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
print_status "Next steps:"
print_status "1. Use 'kubectl port-forward svc/flink-sql-gateway 8083:8083 -n flink-studio' to access SQL Gateway"
print_status "2. Use 'kubectl port-forward svc/flink-session-cluster-rest 8081:8081 -n flink-studio' to access Flink UI"
print_status "3. Test Kafka connectivity with your actual topics and data"
print_status ""
print_status "Example Kafka table creation SQL:"
echo "CREATE TABLE my_kafka_table ("
echo "  id BIGINT,"
echo "  data STRING,"
echo "  event_time TIMESTAMP(3),"
echo "  WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND"
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
