#!/bin/bash

# Script to create Aiven credentials secret for Flink Kafka connectivity
# Creates a single secret containing all Kafka-related credentials and truststore
# Converts PEM CA certificate to JKS truststore format automatically

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_NAMESPACE="flink-studio"
DEFAULT_SECRET_NAME="aiven-credentials"

# Cleanup function for temporary files
cleanup() {
    if [ -n "$TEMP_JKS_FILE" ] && [ -f "$TEMP_JKS_FILE" ]; then
        rm -f "$TEMP_JKS_FILE"
        echo -e "${BLUE}Cleaned up temporary JKS file${NC}"
    fi
}

# Set trap to cleanup on exit
trap cleanup EXIT

echo -e "${BLUE}=== Aiven Credentials Secret Creator ===${NC}"
echo -e "${YELLOW}This script will create a Kubernetes secret containing all Aiven Kafka credentials${NC}"
echo ""

# Check and confirm kubectl context
echo -e "${BLUE}Checking current kubectl context...${NC}"
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "No context found")
if [ "$CURRENT_CONTEXT" = "No context found" ]; then
    echo -e "${RED}❌ No kubectl context found. Please configure kubectl first.${NC}"
    echo "Run: kubectl config use-context <your-context>"
    exit 1
fi

echo -e "${YELLOW}Current kubectl context: ${GREEN}$CURRENT_CONTEXT${NC}"
echo ""
read -p "Is this the correct Kubernetes cluster context? (y/N): " context_confirm
if [[ ! "$context_confirm" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Please switch to the correct context using:${NC}"
    echo "kubectl config use-context <your-desired-context>"
    echo ""
    echo -e "${BLUE}Available contexts:${NC}"
    kubectl config get-contexts
    exit 0
fi

echo -e "${GREEN}✅ Using kubectl context: $CURRENT_CONTEXT${NC}"
echo ""

# Function to prompt for input with default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        eval "$var_name=\"${input:-$default}\""
    else
        read -p "$prompt: " input
        eval "$var_name=\"$input\""
    fi
}

# Function to prompt for sensitive input (hidden)
prompt_sensitive() {
    local prompt="$1"
    local var_name="$2"
    
    read -s -p "$prompt: " input
    echo ""  # New line after hidden input
    eval "$var_name=\"$input\""
}

# Function to validate file exists
validate_file() {
    local file_path="$1"
    if [ ! -f "$file_path" ]; then
        echo -e "${RED}Error: File '$file_path' does not exist${NC}"
        return 1
    fi
    return 0
}

# Collect input from user
echo -e "${YELLOW}Step 1: Basic Configuration${NC}"
prompt_with_default "Kubernetes namespace" "$DEFAULT_NAMESPACE" "NAMESPACE"
prompt_with_default "Secret name" "$DEFAULT_SECRET_NAME" "SECRET_NAME"

echo ""
echo -e "${YELLOW}Step 2: Kafka Credentials${NC}"
prompt_with_default "Kafka username" "" "KAFKA_USERNAME"
prompt_sensitive "Kafka password" "KAFKA_PASSWORD"

echo ""
echo -e "${YELLOW}Step 3: Truststore Configuration${NC}"
prompt_with_default "Path to Kafka CA certificate PEM file" "" "CA_PEM_FILE_PATH"

# Validate CA PEM file exists
if ! validate_file "$CA_PEM_FILE_PATH"; then
    echo -e "${RED}Please provide a valid path to the CA certificate PEM file${NC}"
    exit 1
fi

prompt_sensitive "Truststore password (will be used for the generated JKS file)" "TRUSTSTORE_PASSWORD"

# Generate temporary JKS file path
TEMP_JKS_FILE="/tmp/kafka.truststore.jks.$$"
echo -e "${BLUE}Converting PEM file to JKS truststore...${NC}"

# Convert PEM to JKS using keytool
if keytool -import \
    -alias kafka-ca \
    -file "$CA_PEM_FILE_PATH" \
    -keystore "$TEMP_JKS_FILE" \
    -storepass "$TRUSTSTORE_PASSWORD" \
    -noprompt; then
    echo -e "${GREEN}✅ Successfully converted PEM to JKS truststore${NC}"
    TRUSTSTORE_FILE_PATH="$TEMP_JKS_FILE"
else
    echo -e "${RED}❌ Failed to convert PEM file to JKS truststore${NC}"
    echo -e "${RED}Please check that the PEM file is valid and keytool is installed${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 4: Confirmation${NC}"
echo "Configuration summary:"
echo "  Namespace: $NAMESPACE"
echo "  Secret name: $SECRET_NAME"
echo "  Kafka username: $KAFKA_USERNAME"
echo "  Kafka password: [HIDDEN]"
echo "  CA certificate PEM file: $CA_PEM_FILE_PATH"
echo "  Generated JKS truststore: $TRUSTSTORE_FILE_PATH"
echo "  Truststore password: [HIDDEN]"
echo ""

read -p "Do you want to create the secret with these settings? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Operation cancelled${NC}"
    exit 0
fi

# Check if namespace exists
echo ""
echo -e "${BLUE}Checking if namespace '$NAMESPACE' exists...${NC}"
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo -e "${YELLOW}Namespace '$NAMESPACE' does not exist. Creating it...${NC}"
    kubectl create namespace "$NAMESPACE"
    echo -e "${GREEN}Namespace '$NAMESPACE' created successfully${NC}"
else
    echo -e "${GREEN}Namespace '$NAMESPACE' already exists${NC}"
fi

# Check if secret already exists
echo -e "${BLUE}Checking if secret '$SECRET_NAME' already exists...${NC}"
if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo -e "${YELLOW}Warning: Secret '$SECRET_NAME' already exists in namespace '$NAMESPACE'${NC}"
    read -p "Do you want to delete and recreate it? (y/N): " recreate
    if [[ "$recreate" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Deleting existing secret...${NC}"
        kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE"
        echo -e "${GREEN}Existing secret deleted${NC}"
    else
        echo -e "${YELLOW}Operation cancelled${NC}"
        exit 0
    fi
fi

# Create the secret
echo -e "${BLUE}Creating Aiven credentials secret...${NC}"
kubectl create secret generic "$SECRET_NAME" \
    --from-literal=username="$KAFKA_USERNAME" \
    --from-literal=password="$KAFKA_PASSWORD" \
    --from-literal=truststore-password="$TRUSTSTORE_PASSWORD" \
    --from-file=kafka.truststore.jks="$TRUSTSTORE_FILE_PATH" \
    --namespace="$NAMESPACE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Secret '$SECRET_NAME' created successfully in namespace '$NAMESPACE'${NC}"
    
    # Clean up temporary JKS file
    if [ -f "$TEMP_JKS_FILE" ]; then
        rm -f "$TEMP_JKS_FILE"
        echo -e "${BLUE}Cleaned up temporary JKS file${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}Secret contents:${NC}"
    kubectl describe secret "$SECRET_NAME" -n "$NAMESPACE"
    echo ""
    echo -e "${GREEN}Your Flink deployment can now use this secret for Kafka connectivity!${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Deploy your Flink session cluster: kubectl apply -f manifests/03-flink-session-cluster-gcp.yaml"
    echo "2. Verify the pods can access the secret and truststore file"
    echo "3. Test Kafka connectivity from Flink SQL"
else
    echo -e "${RED}❌ Failed to create secret${NC}"
    # Cleanup will be handled by trap
    exit 1
fi

# Optional: Show how to verify the secret
echo ""
read -p "Do you want to verify the secret was created correctly? (y/N): " verify
if [[ "$verify" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Verifying secret contents...${NC}"
    echo ""
    echo "Keys in the secret:"
    kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data}' | jq -r 'keys[]'
    echo ""
    echo "To test the truststore file in a pod, you can run:"
    echo "keytool -list -keystore /etc/kafka/secrets/kafka.truststore.jks -storepass \$TRUSTSTORE_PASSWORD"
fi
