#!/bin/bash

# Aiven Kafka Truststore Setup Script
# This script converts Aiven CA certificate to JKS truststore and creates Kubernetes secrets

set -e

echo "=== Aiven Kafka Truststore Setup ==="
echo ""

# Check if required tools are installed
command -v keytool >/dev/null 2>&1 || { echo "Error: keytool is required but not installed. Please install Java JDK." >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl is required but not installed." >&2; exit 1; }

# Get CA certificate path from user
echo "Please download the CA certificate (ca.pem) from your Aiven Kafka service console:"
echo "1. Go to your Aiven Kafka service in the console"
echo "2. Navigate to 'Overview' > 'Connection information'"
echo "3. Set Authentication method to 'SASL'"
echo "4. Download the 'ca.pem' file"
echo ""
read -p "Enter the full path to your downloaded ca.pem file: " CA_CERT_PATH

# Validate the CA certificate file exists
if [[ ! -f "$CA_CERT_PATH" ]]; then
    echo "Error: CA certificate file not found at: $CA_CERT_PATH"
    exit 1
fi

echo "Found CA certificate at: $CA_CERT_PATH"

# Set up variables
TRUSTSTORE_PASSWORD="aiven-truststore-password"
TRUSTSTORE_FILE="kafka.truststore.jks"
TEMP_DIR=$(mktemp -d)
TRUSTSTORE_PATH="$TEMP_DIR/$TRUSTSTORE_FILE"

echo ""
echo "Creating JKS truststore..."

# Create JKS truststore from CA certificate
keytool -import \
    -alias aiven-ca \
    -file "$CA_CERT_PATH" \
    -keystore "$TRUSTSTORE_PATH" \
    -storepass "$TRUSTSTORE_PASSWORD" \
    -noprompt \
    -storetype JKS

echo "✓ JKS truststore created successfully"

# Create Kubernetes secrets
echo ""
echo "Creating Kubernetes secrets..."

# Create secret for Kafka Connect namespace
echo "Creating secret in 'kafka' namespace for Kafka Connect..."
kubectl create secret generic kafka-truststore-secret \
    --from-file=kafka.truststore.jks="$TRUSTSTORE_PATH" \
    --from-literal=truststore-password="$TRUSTSTORE_PASSWORD" \
    --namespace=kafka \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Secret created in 'kafka' namespace"

# Create secret for Flink namespace
echo "Creating secret in 'flink-studio' namespace for Flink..."
kubectl create secret generic kafka-truststore-secret \
    --from-file=kafka.truststore.jks="$TRUSTSTORE_PATH" \
    --from-literal=truststore-password="$TRUSTSTORE_PASSWORD" \
    --namespace=flink-studio \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Secret created in 'flink-studio' namespace"

# Verify secrets
echo ""
echo "Verifying secrets..."
echo "Kafka namespace:"
kubectl get secret kafka-truststore-secret -n kafka -o yaml | grep -E "kafka.truststore.jks|truststore-password" | wc -l
echo "Flink namespace:"
kubectl get secret kafka-truststore-secret -n flink-studio -o yaml | grep -E "kafka.truststore.jks|truststore-password" | wc -l

# Clean up
rm -rf "$TEMP_DIR"

echo ""
echo "=== Setup Complete ==="
echo "✓ Truststore created and configured"
echo "✓ Kubernetes secrets created in both 'kafka' and 'flink-studio' namespaces"
echo "✓ Your applications can now connect to Aiven Kafka using SASL_SSL"
echo ""
echo "Truststore details:"
echo "  - Location in pods: /etc/kafka/secrets/kafka.truststore.jks"
echo "  - Password: $TRUSTSTORE_PASSWORD"
echo "  - Type: JKS"
echo ""
echo "Next steps:"
echo "1. Ensure your Flink deployment is updated with truststore configuration"
echo "2. Use SASL_SSL security protocol in your Kafka connections"
echo "3. Reference the truststore in your connector configurations"
