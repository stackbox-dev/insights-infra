#!/bin/bash

# Flink Platform Deployment Script
# This script deploys the entire Flink platform according to the architecture

set -e

# Trap to handle failures and provide rollback information
trap 'echo -e "${RED}[ERROR]${NC} Deployment failed! Run ./cleanup.sh to remove partially deployed resources"; exit 1' ERR

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    print_error "helm is not installed or not in PATH"
    exit 1
fi

# Ask user to select cloud provider
echo ""
echo "Select your cloud provider:"
echo "1) Google Cloud Platform (GCP/GKE)"
echo "2) Microsoft Azure (AKS)"
echo ""
read -p "Enter your choice (1 or 2): " cloud_choice

case $cloud_choice in
    1)
        CLOUD_PROVIDER="gcp"
        MANIFEST_SUFFIX="-gcp"
        print_status "Selected: Google Cloud Platform (GCP/GKE)"
        ;;
    2)
        CLOUD_PROVIDER="azure"
        MANIFEST_SUFFIX="-aks"
        print_status "Selected: Microsoft Azure (AKS)"
        ;;
    *)
        print_error "Invalid choice. Please run the script again and select 1 or 2."
        exit 1
        ;;
esac

# Check current Kubernetes context
print_status "Checking Kubernetes context..."
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "No context set")
if [ "$CURRENT_CONTEXT" = "No context set" ]; then
    print_error "No Kubernetes context is currently set"
    print_error "Please set the correct context with: kubectl config use-context <context-name>"
    exit 1
fi

print_status "Current Kubernetes context: $CURRENT_CONTEXT"
echo ""
print_warning "WARNING: You are about to deploy to the cluster associated with context '$CURRENT_CONTEXT'"
print_warning "Make sure this is the correct cluster for your $CLOUD_PROVIDER deployment!"
echo ""
read -p "Do you want to continue with this context? (y/N): " context_confirm

if [[ ! $context_confirm =~ ^[Yy]$ ]]; then
    print_status "Deployment cancelled by user"
    print_status "Available contexts:"
    kubectl config get-contexts
    print_status ""
    print_status "To switch context, use: kubectl config use-context <context-name>"
    exit 0
fi

print_status "Starting Flink Platform deployment for $CLOUD_PROVIDER..."

# Step 1: Install Flink Kubernetes Operator
print_status "Step 1: Installing Flink Kubernetes Operator..."

# Check cloud provider configuration
if [ "$CLOUD_PROVIDER" = "gcp" ]; then
    print_status "Using default Docker Hub Flink image with GCP configuration"
    
    # SQL Gateway already configured with default image - no changes needed
    print_status "SQL Gateway configured to use default Flink image"
    
    # Setup GCP Workload Identity
    print_status "Setting up GCP Workload Identity..."
    
    # Create service account if it doesn't exist
    if ! gcloud iam service-accounts describe flink-gcs@sbx-stag.iam.gserviceaccount.com >/dev/null 2>&1; then
        print_status "Creating Google Service Account: flink-gcs"
        gcloud iam service-accounts create flink-gcs \
            --display-name="Flink GCS Service Account" \
            --description="Service account for Flink to access GCS" \
            --project=sbx-stag
    else
        print_status "Google Service Account flink-gcs already exists"
    fi
    
    # Grant storage permissions
    print_status "Granting Storage Admin permissions..."
    gsutil iam ch serviceAccount:flink-gcs@sbx-stag.iam.gserviceaccount.com:roles/storage.admin \
        gs://sbx-stag-flink-storage/
        
    print_status "Google Service Account permissions configured successfully"
elif [ "$CLOUD_PROVIDER" = "azure" ]; then
    print_status "Using custom Flink image with Azure configuration"
    
    # SQL Gateway already configured with custom image - no changes needed
    print_status "SQL Gateway configured to use custom Flink image"
    
    # Setup Azure Workload Identity
    print_status "Setting up Azure Workload Identity..."
    
    # Check if managed identity exists
    if ! az identity show --name flink-identity --resource-group UnileverSBXWMS_2 >/dev/null 2>&1; then
        print_error "Azure Managed Identity 'flink-identity' not found!"
        print_error "Please create it first:"
        print_error "az identity create --name flink-identity --resource-group UnileverSBXWMS_2"
        exit 1
    else
        print_status "Azure Managed Identity 'flink-identity' found"
    fi
    
    # Verify storage container exists
    print_status "Verifying Azure storage container exists..."
    if ! az storage container show --name flink --account-name sbxunileverflinkstorage1 >/dev/null 2>&1; then
        print_warning "Storage container 'flink' not found. Creating it..."
        az storage container create \
            --name flink \
            --account-name sbxunileverflinkstorage1 \
            --resource-group UnileverSBXWMS_2
        print_status "Storage container 'flink' created successfully"
    else
        print_status "Storage container 'flink' exists"
    fi
    
    # Verify federated credential exists
    if ! az identity federated-credential show \
        --identity-name flink-identity \
        --resource-group UnileverSBXWMS_2 \
        --name flink-federated-credential >/dev/null 2>&1; then
        print_warning "Federated credential not found. Creating it..."
        az identity federated-credential create \
            --name flink-federated-credential \
            --identity-name flink-identity \
            --resource-group UnileverSBXWMS_2 \
            --issuer "https://centralindia.oic.prod-aks.azure.com/f66fae02-5d36-495b-bfe0-78a6ff9f8e6e/e2b8aeab-2ec7-4529-8541-b03b12297935/" \
            --subject system:serviceaccount:flink-studio:flink
        print_status "Federated credential created successfully"
    else
        print_status "Federated credential already exists"
    fi
    
    print_status "Azure Workload Identity setup completed"
fi
print_status ""

helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.12.1/
helm repo update

if ! helm list -n flink-system | grep -q flink-kubernetes-operator; then
    kubectl create namespace flink-system --dry-run=client -o yaml | kubectl apply -f -
    helm install flink-kubernetes-operator flink-operator-repo/flink-kubernetes-operator \
        --namespace flink-system \
        --create-namespace \
        --wait
    print_status "Flink Kubernetes Operator installed successfully"
else
    print_warning "Flink Kubernetes Operator already installed, skipping..."
fi

# Step 2: Deploy platform namespace and RBAC
print_status "Step 2: Creating platform namespace and RBAC for $CLOUD_PROVIDER..."
kubectl apply -f manifests/01-namespace.yaml

# Ensure namespace is ready before proceeding
print_status "Verifying namespace is active..."
for i in {1..12}; do
    NAMESPACE_PHASE=$(kubectl get namespace flink-studio -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    if [ "$NAMESPACE_PHASE" = "Active" ]; then
        print_status "Namespace flink-studio is active and ready"
        break
    else
        print_warning "Waiting for namespace to be active... Status: $NAMESPACE_PHASE (attempt $i/12)"
        sleep 5
    fi
    
    if [ $i -eq 12 ]; then
        print_error "Namespace failed to become active within 60 seconds"
        exit 1
    fi
done

kubectl apply -f manifests/02-rbac${MANIFEST_SUFFIX}.yaml
kubectl apply -f manifests/05-resource-quotas.yaml

# Configure Workload Identity binding for GCP
if [ "$CLOUD_PROVIDER" = "gcp" ]; then
    print_status "Configuring Workload Identity binding..."
    
    # Allow the Kubernetes service account to impersonate the Google service account
    gcloud iam service-accounts add-iam-policy-binding flink-gcs@sbx-stag.iam.gserviceaccount.com \
        --role roles/iam.workloadIdentityUser \
        --member "serviceAccount:sbx-stag.svc.id.goog[flink-studio/flink]" \
        --project=sbx-stag
    
    print_status "Workload Identity binding configured successfully"
    print_status "Kubernetes Service Account: flink-studio/flink"
    print_status "Google Service Account: flink-gcs@sbx-stag.iam.gserviceaccount.com"
fi

# Step 3: Check for Aiven credentials secret
print_status "Step 3: Checking for Aiven credentials secret..."
if ! kubectl get secret aiven-credentials -n flink-studio --ignore-not-found 2>/dev/null | grep -q aiven-credentials; then
    print_error "Aiven credentials secret not found!"
    print_error "The Flink deployment requires the 'aiven-credentials' secret to connect to Aiven Kafka."
    print_error ""
    print_error "Please run the Aiven credentials setup script first:"
    print_error "  ./scripts/create-aiven-secret.sh"
    print_error ""
    print_error "This script will:"
    print_error "1. Prompt you for Kafka username and password"
    print_error "2. Ask for the path to your Kafka CA certificate PEM file"
    print_error "3. Convert the PEM file to JKS truststore format"
    print_error "4. Create the consolidated Kubernetes secret with all credentials"
    print_error ""
    read -p "Do you want to run the create-aiven-secret.sh script now? (y/N): " run_script
    if [[ $run_script =~ ^[Yy]$ ]]; then
        print_status "Running create-aiven-secret.sh script..."
        if [ -f "./scripts/create-aiven-secret.sh" ]; then
            ./scripts/create-aiven-secret.sh
            if [ $? -eq 0 ]; then
                print_status "Aiven credentials secret created successfully!"
            else
                print_error "Failed to create Aiven credentials secret. Deployment cannot continue."
                exit 1
            fi
        else
            print_error "create-aiven-secret.sh script not found in ./scripts/ directory"
            exit 1
        fi
    else
        print_error "Deployment cannot continue without Aiven credentials secret. Exiting."
        exit 1
    fi
    
    # Verify the secret was created
    if ! kubectl get secret aiven-credentials -n flink-studio --ignore-not-found 2>/dev/null | grep -q aiven-credentials; then
        print_error "Aiven credentials secret still not found after running the script."
        exit 1
    fi
else
    print_status "Aiven credentials secret found"
    
    # Verify the secret has all required keys
    print_status "Verifying secret contains all required keys..."
    SECRET_KEYS=$(kubectl get secret aiven-credentials -n flink-studio -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null || echo "")
    REQUIRED_KEYS=("username" "password" "truststore-password" "kafka.truststore.jks")
    MISSING_KEYS=()
    
    for key in "${REQUIRED_KEYS[@]}"; do
        if ! echo "$SECRET_KEYS" | grep -q "^$key$"; then
            MISSING_KEYS+=("$key")
        fi
    done
    
    if [ ${#MISSING_KEYS[@]} -gt 0 ]; then
        print_error "Aiven credentials secret is missing required keys: ${MISSING_KEYS[*]}"
        print_error "Please recreate the secret using: ./scripts/create-aiven-secret.sh"
        exit 1
    else
        print_status "All required keys found in Aiven credentials secret"
    fi
fi

# Step 4: Deploy Flink Session Cluster
print_status "Step 4: Deploying Flink Session Cluster for $CLOUD_PROVIDER..."
kubectl apply -f manifests/03-flink-session-cluster${MANIFEST_SUFFIX}.yaml

# Wait for Flink cluster to be ready with better timeout handling
print_status "Waiting for Flink Session Cluster to be ready (this may take several minutes)..."

# Check FlinkDeployment status instead of using kubectl wait
print_status "Checking FlinkDeployment status..."
for i in {1..60}; do
    FLINK_STATUS=$(kubectl get flinkdeployment flink-session-cluster -n flink-studio -o jsonpath='{.status.lifecycleState}' 2>/dev/null || echo "UNKNOWN")
    JM_STATUS=$(kubectl get flinkdeployment flink-session-cluster -n flink-studio -o jsonpath='{.status.jobManagerDeploymentStatus}' 2>/dev/null || echo "UNKNOWN")
    
    if [ "$FLINK_STATUS" = "STABLE" ] && [ "$JM_STATUS" = "READY" ]; then
        print_status "Flink Session Cluster is ready! (Status: $FLINK_STATUS, JobManager: $JM_STATUS)"
        break
    elif [ "$FLINK_STATUS" = "DEPLOYED" ]; then
        print_status "Flink Session Cluster is deployed and ready! (Status: $FLINK_STATUS, JobManager: $JM_STATUS)"
        break
    else
        print_warning "Waiting for Flink cluster... Status: $FLINK_STATUS, JobManager: $JM_STATUS (attempt $i/60)"
        sleep 10
    fi
    
    if [ $i -eq 60 ]; then
        print_error "Flink Session Cluster failed to become ready within 10 minutes"
        print_error "Final Status: $FLINK_STATUS, JobManager: $JM_STATUS"
        print_error "Check the logs with: kubectl logs -n flink-system deployment/flink-kubernetes-operator"
        print_error "Check cluster status with: kubectl describe flinkdeployment flink-session-cluster -n flink-studio"
        exit 1
    fi
done

# Additional verification that JobManager is accessible
print_status "Verifying Flink JobManager is accessible..."
for i in {1..30}; do
    if kubectl get service flink-session-cluster -n flink-studio >/dev/null 2>&1; then
        print_status "Flink JobManager service is ready"
        break
    fi
    print_warning "Waiting for Flink JobManager service... (attempt $i/30)"
    sleep 10
done

# Step 5: Deploy Flink SQL Gateway
print_status "Step 5: Deploying Flink SQL Gateway..."
kubectl apply -f manifests/04-flink-sql-gateway.yaml

# Wait for SQL Gateway to be ready
print_status "Waiting for SQL Gateway to be ready..."
if ! kubectl wait --for=condition=Available deployment/flink-sql-gateway -n flink-studio --timeout=180s; then
    print_warning "SQL Gateway deployment may need more time. Continuing with deployment..."
fi

# Step 6: Apply security policies (optional)
print_status "Step 6: Applying Network Policies..."
kubectl apply -f manifests/06-network-policies.yaml

print_status "Deployment completed successfully!"
print_status ""
print_status "=== Access Information ==="
print_status "Flink UI: kubectl port-forward svc/flink-session-cluster 8081:80 -n flink-studio"
print_status "SQL Gateway: kubectl port-forward svc/flink-sql-gateway 8083:80 -n flink-studio"
print_status ""

# Cloud-specific information
if [ "$CLOUD_PROVIDER" = "gcp" ]; then
    print_status "=== GCP-Specific Configuration ==="
    print_status "Storage: gs://sbx-stag-flink-storage"
    print_status "Authentication: GKE Workload Identity"
    print_status ""
    print_status "Workload Identity Configuration:"
    print_status "- Google Service Account: flink-gcs@sbx-stag.iam.gserviceaccount.com"
    print_status "- Kubernetes Service Account: flink-studio/flink"
    print_status "- Workload Identity Pool: sbx-stag.svc.id.goog"
    print_status ""
    print_status "Security Benefits:"
    print_status "✅ No service account keys stored in cluster"
    print_status "✅ Automatic credential rotation"
    print_status "✅ IAM-based access control"
    print_status "✅ Reduced security risk"
    print_status ""
    print_status "To verify GCS access from a pod:"
    print_status "kubectl exec -it deployment/flink-session-cluster -n flink-studio -- gsutil ls gs://sbx-stag-flink-storage/"
    print_status ""
    print_status "To verify Workload Identity is working:"
    print_status "kubectl exec -it deployment/flink-session-cluster -n flink-studio -- gcloud auth list"
elif [ "$CLOUD_PROVIDER" = "azure" ]; then
    print_status "=== Azure-Specific Configuration ==="
    print_status "Storage: abfss://flink@sbxunileverflinkstorage1.dfs.core.windows.net"
    print_status "Authentication: Azure Workload Identity"
    print_status ""
    print_status "Workload Identity Configuration:"
    print_status "- Managed Identity: flink-identity"
    print_status "- Client ID: 911d60a1-3770-40cb-978b-8b7342bf02b8"
    print_status "- Kubernetes Service Account: flink-studio/flink"
    print_status "- Storage Account: sbxunileverflinkstorage1"
    print_status "- Resource Group: UnileverSBXWMS_2"
    print_status ""
    print_status "Security Benefits:"
    print_status "✅ No storage account keys stored in cluster"
    print_status "✅ Automatic credential rotation"
    print_status "✅ Azure RBAC-based access control"
    print_status "✅ Reduced security risk"
    print_status ""
    print_status "To verify Azure storage access from a pod:"
    print_status "kubectl exec -it deployment/flink-session-cluster -n flink-studio -- az storage container list --account-name sbxunileverflinkstorage1"
    print_status ""
    print_status "TaskManager pods will run on spot instances for cost optimization"
    print_status "RocksDB storage: 50GB per TaskManager pod"
fi

print_status ""
print_status "To access via Ingress, ensure your ingress controller is properly configured"
