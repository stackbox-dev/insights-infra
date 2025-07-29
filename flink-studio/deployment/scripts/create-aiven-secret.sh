#!/bin/bash

# Script to create Aiven Kafka credentials secret in Kubernetes
# This script will prompt for credentials and confirm the target context/namespace

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="flink-studio"
SECRET_NAME="aiven-kafka-credentials"

echo -e "${BLUE}=== Aiven Kafka Credentials Setup Script ===${NC}"
echo

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed or not in PATH${NC}"
    exit 1
fi

# Get current context
CURRENT_CONTEXT=$(kubectl config current-context)
echo -e "${YELLOW}Current Kubernetes context:${NC} ${CURRENT_CONTEXT}"

# Get current namespace (if set)
CURRENT_NAMESPACE=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null || echo "default")
echo -e "${YELLOW}Current namespace:${NC} ${CURRENT_NAMESPACE}"
echo

# Confirm context
echo -e "${YELLOW}This script will create the secret '${SECRET_NAME}' in namespace '${NAMESPACE}'${NC}"
read -p "Do you want to proceed with this context and namespace? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Operation cancelled.${NC}"
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo -e "${YELLOW}Namespace '$NAMESPACE' does not exist.${NC}"
    read -p "Do you want to create it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl create namespace "$NAMESPACE"
        echo -e "${GREEN}Namespace '$NAMESPACE' created successfully.${NC}"
    else
        echo -e "${RED}Cannot proceed without the namespace. Exiting.${NC}"
        exit 1
    fi
fi

# Check if secret already exists
if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &> /dev/null; then
    echo -e "${YELLOW}Secret '$SECRET_NAME' already exists in namespace '$NAMESPACE'.${NC}"
    read -p "Do you want to replace it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE"
        echo -e "${GREEN}Existing secret deleted.${NC}"
    else
        echo -e "${RED}Operation cancelled.${NC}"
        exit 1
    fi
fi

echo
echo -e "${BLUE}Please provide your Aiven Kafka credentials:${NC}"
echo

# Prompt for credentials
read -p "Bootstrap Servers (e.g., kafka-12345-project.aivencloud.com:12345): " BOOTSTRAP_SERVERS
if [[ -z "$BOOTSTRAP_SERVERS" ]]; then
    echo -e "${RED}Bootstrap servers cannot be empty${NC}"
    exit 1
fi

read -p "Username: " USERNAME
if [[ -z "$USERNAME" ]]; then
    echo -e "${RED}Username cannot be empty${NC}"
    exit 1
fi

read -s -p "Password: " PASSWORD
echo
if [[ -z "$PASSWORD" ]]; then
    echo -e "${RED}Password cannot be empty${NC}"
    exit 1
fi

read -p "Schema Registry URL (e.g., https://schema-registry-12345-project.aivencloud.com): " SCHEMA_REGISTRY_URL
if [[ -z "$SCHEMA_REGISTRY_URL" ]]; then
    echo -e "${RED}Schema Registry URL cannot be empty${NC}"
    exit 1
fi

echo
echo -e "${YELLOW}Summary of credentials to be stored:${NC}"
echo "Bootstrap Servers: $BOOTSTRAP_SERVERS"
echo "Username: $USERNAME"
echo "Password: [HIDDEN]"
echo "Schema Registry URL: $SCHEMA_REGISTRY_URL"
echo "Target namespace: $NAMESPACE"
echo "Secret name: $SECRET_NAME"
echo

read -p "Create the secret with these values? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Operation cancelled.${NC}"
    exit 1
fi

# Create the secret
echo -e "${BLUE}Creating Kubernetes secret...${NC}"

kubectl create secret generic "$SECRET_NAME" \
    --from-literal=bootstrap-servers="$BOOTSTRAP_SERVERS" \
    --from-literal=username="$USERNAME" \
    --from-literal=password="$PASSWORD" \
    --from-literal=schema-registry-url="$SCHEMA_REGISTRY_URL" \
    --namespace="$NAMESPACE"

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ Secret '$SECRET_NAME' created successfully in namespace '$NAMESPACE'${NC}"
    echo
    echo -e "${BLUE}You can now verify the secret with:${NC}"
    echo "kubectl get secret $SECRET_NAME -n $NAMESPACE"
    echo "kubectl describe secret $SECRET_NAME -n $NAMESPACE"
    echo
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Apply your Flink deployment: kubectl apply -f 03-flink-session-cluster-gcp.yaml"
    echo "2. Your SQL queries can now use environment variables like \${AIVEN_KAFKA_BOOTSTRAP_SERVERS}"
    echo
else
    echo -e "${RED}✗ Failed to create secret${NC}"
    exit 1
fi

# Optional: Show secret contents (base64 encoded)
read -p "Do you want to view the created secret details? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Secret details:${NC}"
    kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o yaml
fi

echo -e "${GREEN}Script completed successfully!${NC}"
