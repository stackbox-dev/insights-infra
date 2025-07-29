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
    print_status "Using default Docker Hub Flink image with Azure configuration"
    
    # SQL Gateway already configured with default image - no changes needed
    print_status "SQL Gateway configured to use default Flink image"
    
    # Check if Azure storage account key is set
    if ! kubectl get secret azure-storage-secret -n flink-studio --ignore-not-found 2>/dev/null | grep -q azure-storage-secret; then
        print_error "Azure storage account key not configured!"
        print_error "Please run:"
        print_error "kubectl create secret generic azure-storage-secret --from-literal=storage-account-key=YOUR_ACTUAL_STORAGE_ACCOUNT_KEY -n flink-studio"
        read -p "Have you set the Azure storage account key? (y/N): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            print_error "Deployment cannot continue without storage account key. Exiting."
            exit 1
        fi
    else
        print_status "Azure storage secret found"
    fi
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

# Deploy cloud-specific configurations
# Note: Hadoop config is needed for SQL Gateway to access GCS/Azure storage
if [ "$CLOUD_PROVIDER" = "gcp" ]; then
    print_status "Deploying Hadoop configuration for SQL Gateway GCS access..."
    kubectl apply -f manifests/02-hadoop-config-gcp.yaml
elif [ "$CLOUD_PROVIDER" = "azure" ]; then
    print_status "Deploying Hadoop configuration for SQL Gateway Azure storage access..."
    kubectl apply -f manifests/02-hadoop-config-aks.yaml
fi

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

# Step 3: Check for Kafka truststore secret
print_status "Step 3: Checking for Kafka truststore secret..."
if ! kubectl get secret kafka-truststore-secret -n flink-studio --ignore-not-found 2>/dev/null | grep -q kafka-truststore-secret; then
    print_error "Kafka truststore secret not found!"
    print_error "The Flink deployment requires the Kafka truststore secret to connect to Aiven Kafka."
    print_error ""
    print_error "Please run the truststore setup script first:"
    print_error "  ./setup-aiven-truststore.sh"
    print_error ""
    print_error "This script will:"
    print_error "1. Prompt you to download the ca.pem file from Aiven console"
    print_error "2. Convert it to JKS truststore format"
    print_error "3. Create the required Kubernetes secrets"
    print_error ""
    read -p "Have you completed the truststore setup? (y/N): " truststore_confirm
    if [[ ! $truststore_confirm =~ ^[Yy]$ ]]; then
        print_error "Deployment cannot continue without truststore secret. Exiting."
        exit 1
    fi
    
    # Verify again after user confirmation
    if ! kubectl get secret kafka-truststore-secret -n flink-studio --ignore-not-found 2>/dev/null | grep -q kafka-truststore-secret; then
        print_error "Truststore secret still not found. Please run ./setup-aiven-truststore.sh"
        exit 1
    fi
else
    print_status "Kafka truststore secret found"
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
    print_status "Storage: abfss://flink@sbxstagflinkstorage.dfs.core.windows.net"
    print_status "Authentication: Storage Account Key"
    print_status ""
    print_warning "Make sure you have:"
    print_warning "1. Created Azure Storage Account: sbxstagflinkstorage"
    print_warning "2. Created blob container: flink"  
    print_warning "3. Enabled hierarchical namespace (Data Lake Gen2)"
    print_warning "4. Set the storage account key secret in Kubernetes:"
    print_warning ""
    print_status "To set storage key:"
    print_status "kubectl create secret generic azure-storage-secret --from-literal=storage-account-key=YOUR_ACTUAL_KEY -n flink-studio"
fi

print_status ""
print_status "To access via Ingress, ensure your ingress controller is properly configured"
