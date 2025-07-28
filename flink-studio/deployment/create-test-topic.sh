#!/bin/bash

# Google Cloud Managed Kafka Topic Creation Script
# This script creates a test topic using a service account without affecting your local gcloud auth
# It uses a temporary gcloud configuration to isolate the authentication
#
# Prerequisites:
# - kubectl configured and connected to the cluster
# - gcloud CLI installed
# - Either: gcp-service-account-key.json in current directory OR gcp-service-account-key secret in K8s
#
# Usage: ./create-test-topic.sh [topic-name]

set -e

# Cleanup function
cleanup() {
    # Remove temporary gcloud config and service account key
    rm -rf /tmp/gcloud-temp-config 2>/dev/null || true
    rm -f /tmp/gcp-service-account-key.json 2>/dev/null || true
    
    # Restore original gcloud config if it was backed up
    if [ ! -z "$ORIGINAL_GCLOUD_CONFIG" ] && [ -d "$ORIGINAL_GCLOUD_CONFIG" ]; then
        export CLOUDSDK_CONFIG="$ORIGINAL_GCLOUD_CONFIG"
    fi
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

# Configuration
NAMESPACE="flink-studio" 
KAFKA_CLUSTER="sbx-kafka-cluster"
TEST_TOPIC="${1:-flink-test-topic}"
SERVICE_ACCOUNT_SECRET="gcp-service-account-key"

print_status "Creating Kafka topic using temporary gcloud configuration..."
print_status "Target cluster: $KAFKA_CLUSTER"
print_status "Topic to create: $TEST_TOPIC"
print_status "Namespace: $NAMESPACE"
print_status "Service Account Secret: $SERVICE_ACCOUNT_SECRET"
print_status "=========================================="

# Check if gcloud is available
if ! command -v gcloud &> /dev/null; then
    print_error "✗ gcloud CLI not available"
    print_warning "  Install gcloud CLI to manage Kafka topics"
    exit 1
fi

# Store original gcloud config
ORIGINAL_GCLOUD_CONFIG="$CLOUDSDK_CONFIG"

# Create temporary gcloud configuration directory
TEMP_GCLOUD_CONFIG="/tmp/gcloud-temp-config"
mkdir -p "$TEMP_GCLOUD_CONFIG"
export CLOUDSDK_CONFIG="$TEMP_GCLOUD_CONFIG"

print_status "✓ Created temporary gcloud configuration: $TEMP_GCLOUD_CONFIG"

# Get service account key
LOCAL_SA_KEY="./gcp-service-account-key.json"
TEMP_SA_KEY="/tmp/gcp-service-account-key.json"

if [ -f "$LOCAL_SA_KEY" ]; then
    print_status "Using local service account key file: $LOCAL_SA_KEY"
    SA_KEY_FILE="$LOCAL_SA_KEY"
else
    print_status "Local key file not found, extracting from Kubernetes secret..."
    if kubectl get secret $SERVICE_ACCOUNT_SECRET -n $NAMESPACE >/dev/null 2>&1; then
        kubectl get secret $SERVICE_ACCOUNT_SECRET -n $NAMESPACE -o jsonpath='{.data.service-account\.json}' | base64 -d > "$TEMP_SA_KEY"
        SA_KEY_FILE="$TEMP_SA_KEY"
        print_status "✓ Service account key extracted from Kubernetes secret"
    else
        print_error "✗ Neither local key file nor Kubernetes secret found"
        print_warning "  Expected local file: $LOCAL_SA_KEY"
        print_warning "  Expected secret name: $SERVICE_ACCOUNT_SECRET"
        exit 1
    fi
fi

# Validate service account key
PROJECT_ID=$(jq -r '.project_id' "$SA_KEY_FILE" 2>/dev/null || echo "")
CLIENT_EMAIL=$(jq -r '.client_email' "$SA_KEY_FILE" 2>/dev/null || echo "")

if [ -z "$PROJECT_ID" ] || [ -z "$CLIENT_EMAIL" ]; then
    print_error "✗ Invalid service account key"
    exit 1
fi

print_status "✓ Service account key validated"
print_status "  - Project ID: $PROJECT_ID"
print_status "  - Client Email: $CLIENT_EMAIL"

# Activate service account in temporary config
print_status "Activating service account in temporary configuration..."
if gcloud auth activate-service-account --key-file="$SA_KEY_FILE" --quiet 2>/dev/null; then
    print_status "✓ Service account activated in temporary config"
    
    # Set project
    gcloud config set project "$PROJECT_ID" --quiet
    print_status "✓ Project set to: $PROJECT_ID"
    
    # Check if topic already exists
    print_status "Checking if topic exists: $TEST_TOPIC"
    TOPIC_EXISTS=$(gcloud managed-kafka topics list --cluster=$KAFKA_CLUSTER --location=asia-south1 --format="value(name)" --filter="name:$TEST_TOPIC" 2>/dev/null || echo "")
    
    if [ -z "$TOPIC_EXISTS" ]; then
        print_status "Topic not found. Attempting to create: $TEST_TOPIC"
        if gcloud managed-kafka topics create $TEST_TOPIC \
            --cluster=$KAFKA_CLUSTER \
            --location=asia-south1 \
            --partitions=3 \
            --replication-factor=3 2>/dev/null; then
            print_status "✓ Topic created successfully: $TEST_TOPIC"
            
            # Verify topic creation
            sleep 3
            VERIFY_TOPIC=$(gcloud managed-kafka topics list --cluster=$KAFKA_CLUSTER --location=asia-south1 --format="value(name)" --filter="name:$TEST_TOPIC" 2>/dev/null || echo "")
            if [ ! -z "$VERIFY_TOPIC" ]; then
                print_status "✓ Topic creation verified: $TEST_TOPIC"
            else
                print_warning "⚠ Topic may still be initializing"
            fi
        else
            print_error "✗ Failed to create topic: $TEST_TOPIC"
            print_warning "  Possible reasons:"
            print_warning "  - Service account lacks managed-kafka.admin or equivalent role"
            print_warning "  - Topic name conflicts with existing topic"
            print_warning "  - Cluster permissions or networking issues"
            print_warning ""
            print_warning "  You can create the topic manually with:"
            print_warning "  gcloud managed-kafka topics create $TEST_TOPIC --cluster=$KAFKA_CLUSTER --location=asia-south1"
            print_warning ""
            print_warning "  Continuing without topic creation - connectivity test will work if topic exists"
        fi
    else
        print_status "✓ Topic already exists: $TEST_TOPIC"
        print_status "  Skipping topic creation as requested"
    fi
    
else
    print_error "✗ Failed to activate service account"
    exit 1
fi

print_status ""
print_status "=========================================="
print_status "Topic management completed!"
print_status ""
print_status "✓ Your local gcloud authentication remains unchanged"
print_status "✓ Service account validation successful"
print_status ""
print_status "Topic status for '$TEST_TOPIC':"
if [ ! -z "$TOPIC_EXISTS" ]; then
    print_status "✓ Topic exists and is ready for use with Flink"
elif [ ! -z "$VERIFY_TOPIC" ]; then
    print_status "✓ Topic was created and is ready for use with Flink"
else
    print_warning "⚠ Topic may not exist - check manually or create it"
    print_warning "  Manual creation: gcloud managed-kafka topics create $TEST_TOPIC --cluster=$KAFKA_CLUSTER --location=asia-south1"
fi
print_status ""
print_status "You can now run the connectivity test script:"
print_status "  ./test-kafka-connectivity.sh"
