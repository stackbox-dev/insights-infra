#!/bin/bash

# GCP Service Account Authentication Verification Script
# This script helps verify that service account key authentication is properly configured
# Run this inside a pod to test GCS access with service account JSON key

set -e

echo "=== GCP Service Account Authentication Verification ==="
echo ""

# Check if we're running in a Kubernetes pod
if [ -f /var/run/secrets/kubernetes.io/serviceaccount/token ]; then
    echo "✓ Running in Kubernetes pod"
    NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
    echo "  Namespace: $NAMESPACE"
else
    echo "✗ Not running in Kubernetes pod"
    exit 1
fi

# Check service account key file
echo ""
echo "Checking service account key file..."
if [ -f "/opt/flink/conf/service-account.json" ]; then
    echo "✓ Service account key file found: /opt/flink/conf/service-account.json"
    
    # Check if the file is valid JSON
    if cat /opt/flink/conf/service-account.json | jq . > /dev/null 2>&1; then
        echo "✓ Service account key file is valid JSON"
        
        # Extract service account email
        SERVICE_ACCOUNT_EMAIL=$(cat /opt/flink/conf/service-account.json | jq -r '.client_email')
        echo "✓ Service account email: $SERVICE_ACCOUNT_EMAIL"
    else
        echo "✗ Service account key file is not valid JSON"
        exit 1
    fi
else
    echo "✗ Service account key file not found at /opt/flink/conf/service-account.json"
    echo "  Check if the Kubernetes secret is properly mounted"
    exit 1
fi

# Check GOOGLE_APPLICATION_CREDENTIALS environment variable
echo ""
echo "Checking environment variables..."
if [ "$GOOGLE_APPLICATION_CREDENTIALS" = "/opt/flink/conf/service-account.json" ]; then
    echo "✓ GOOGLE_APPLICATION_CREDENTIALS is correctly set: $GOOGLE_APPLICATION_CREDENTIALS"
else
    echo "✗ GOOGLE_APPLICATION_CREDENTIALS is not set correctly"
    echo "  Expected: /opt/flink/conf/service-account.json"
    echo "  Actual: $GOOGLE_APPLICATION_CREDENTIALS"
    exit 1
fi

# Test authentication by getting an access token
echo ""
echo "Testing service account authentication..."
if command -v gcloud >/dev/null 2>&1; then
    # Use gcloud to activate service account and test
    gcloud auth activate-service-account --key-file=/opt/flink/conf/service-account.json --quiet
    
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "$SERVICE_ACCOUNT_EMAIL"; then
        echo "✓ Service account authentication successful"
    else
        echo "✗ Service account authentication failed"
        exit 1
    fi
else
    echo "⚠ gcloud not available - skipping direct authentication test"
fi

# Test GCS access
echo ""
echo "Testing GCS access..."
GCS_BUCKET="gs://sbx-stag-flink-storage"

# Try to list bucket contents
if gsutil ls "$GCS_BUCKET/" > /dev/null 2>&1; then
    echo "✓ GCS bucket access successful: $GCS_BUCKET"
else
    echo "✗ GCS bucket access failed: $GCS_BUCKET"
    echo "  Check bucket permissions for service account: $SERVICE_ACCOUNT_EMAIL"
    echo "  Required permission: Storage Admin or Storage Object Admin"
    exit 1
fi

# Test write access by creating a test file
TEST_FILE="service-account-test-$(date +%s).txt"
echo "Test from service account authentication verification" | gsutil cp - "$GCS_BUCKET/test/$TEST_FILE"

if [ $? -eq 0 ]; then
    echo "✓ GCS write access successful"
    # Clean up test file
    gsutil rm "$GCS_BUCKET/test/$TEST_FILE" > /dev/null 2>&1
else
    echo "✗ GCS write access failed"
    exit 1
fi

# Test Hadoop/Flink GCS configuration
echo ""
echo "Testing Hadoop GCS configuration..."
if [ -f "$HADOOP_CONF_DIR/core-site.xml" ]; then
    echo "✓ Hadoop configuration found: $HADOOP_CONF_DIR/core-site.xml"
    
    # Check if service account key path is configured
    if grep -q "/opt/flink/conf/service-account.json" "$HADOOP_CONF_DIR/core-site.xml"; then
        echo "✓ Service account key path configured in Hadoop"
    else
        echo "✗ Service account key path not found in Hadoop configuration"
        exit 1
    fi
    
    # Check if service account authentication is enabled
    if grep -q "google.cloud.auth.service.account.enable.*true" "$HADOOP_CONF_DIR/core-site.xml"; then
        echo "✓ Service account authentication enabled in Hadoop"
    else
        echo "✗ Service account authentication not enabled in Hadoop configuration"
        exit 1
    fi
else
    echo "✗ Hadoop configuration not found"
    exit 1
fi

echo ""
echo "=== All service account authentication checks passed! ==="
echo ""
echo "Your Flink deployment should be able to access GCS using the service account key."
echo "Service Account: $SERVICE_ACCOUNT_EMAIL"
echo "GCS Bucket: $GCS_BUCKET"
echo "Key File: /opt/flink/conf/service-account.json"
