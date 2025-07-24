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

print_status "Starting Flink Platform deployment for $CLOUD_PROVIDER..."

# Step 1: Install Flink Kubernetes Operator
print_status "Step 1: Installing Flink Kubernetes Operator..."

# Check if custom image is required and update SQL Gateway image
if [ "$CLOUD_PROVIDER" = "gcp" ]; then
    print_warning "Make sure you have built and pushed the custom GCS-enabled Flink image:"
    print_warning "cd gcp && docker build -t asia-docker.pkg.dev/sbx-ci-cd/private/flink-gke:2.0.0-scala_2.12-java21 ."
    print_warning "cd gcp && docker push asia-docker.pkg.dev/sbx-ci-cd/private/flink-gke:2.0.0-scala_2.12-java21"
    # Update SQL Gateway to use GCP image - using more reliable replacement
    GCP_IMAGE="asia-docker.pkg.dev/sbx-ci-cd/private/flink-gke:2.0.0-scala_2.12-java21"
    if ! grep -q "$GCP_IMAGE" manifests/04-flink-sql-gateway.yaml; then
        print_warning "SQL Gateway already configured with GCP image"
    else
        print_status "SQL Gateway image already configured for GCP"
    fi
    
    # Create GCP Service Account and Kubernetes Secret
    print_status "Setting up GCP Service Account authentication..."
    
    # Check if service account key file already exists
    if [ ! -f "gcp-service-account-key.json" ]; then
        print_status "Creating Google Service Account and downloading key..."
        
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
            
        # Generate and download service account key
        print_status "Generating service account key..."
        gcloud iam service-accounts keys create gcp-service-account-key.json \
            --iam-account=flink-gcs@sbx-stag.iam.gserviceaccount.com \
            --project=sbx-stag
            
        print_status "Service account key saved to: gcp-service-account-key.json"
    else
        print_status "Service account key file already exists: gcp-service-account-key.json"
    fi
    
    # Create Kubernetes secret from the service account key
    print_status "Creating Kubernetes secret for GCP service account..."
    if kubectl get secret gcp-service-account-key -n flink-studio >/dev/null 2>&1; then
        print_status "Kubernetes secret already exists, updating..."
        kubectl delete secret gcp-service-account-key -n flink-studio
    fi
    
    kubectl create secret generic gcp-service-account-key \
        --from-file=service-account.json=gcp-service-account-key.json \
        -n flink-studio
        
    print_status "Kubernetes secret 'gcp-service-account-key' created successfully"
    
    # Verify the secret was created correctly
    if kubectl get secret gcp-service-account-key -n flink-studio -o jsonpath='{.data.service-account\.json}' | base64 -d | jq . >/dev/null 2>&1; then
        print_status "Secret verification: Service account key is valid JSON"
    else
        print_error "Secret verification failed: Service account key is not valid JSON"
        exit 1
    fi
elif [ "$CLOUD_PROVIDER" = "azure" ]; then
    print_warning "Make sure you have built and pushed the custom Azure-enabled Flink image:"
    print_warning "cd azure && docker build -t sbxstag.azurecr.io/flink-aks:2.0.0-scala_2.12-azure ."
    print_warning "docker push sbxstag.azurecr.io/flink-aks:2.0.0-scala_2.12-azure"
    # Update SQL Gateway to use Azure image
    sed -i '' 's|image: asia-docker.pkg.dev/sbx-ci-cd/private/flink-gke:2.0.0-scala_2.12-java21|image: sbxstag.azurecr.io/flink-aks:2.0.0-scala_2.12-azure|g' manifests/04-flink-sql-gateway.yaml
    
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
kubectl apply -f manifests/02-rbac${MANIFEST_SUFFIX}.yaml
kubectl apply -f manifests/02-storage${MANIFEST_SUFFIX}.yaml
kubectl apply -f manifests/05-resource-quotas.yaml

# Step 3: Deploy Flink Session Cluster
print_status "Step 3: Deploying Flink Session Cluster for $CLOUD_PROVIDER..."
kubectl apply -f manifests/03-flink-session-cluster${MANIFEST_SUFFIX}.yaml

# Wait for Flink cluster to be ready with better timeout handling
print_status "Waiting for Flink Session Cluster to be ready (this may take several minutes)..."
if ! kubectl wait --for=condition=Ready flinkdeployment/flink-session-cluster -n flink-studio --timeout=600s; then
    print_error "Flink Session Cluster failed to become ready within 10 minutes"
    print_error "Check the logs with: kubectl logs -n flink-system deployment/flink-kubernetes-operator"
    print_error "Check cluster status with: kubectl get flinkdeployment -n flink-studio"
    exit 1
fi

# Additional verification that JobManager is accessible
print_status "Verifying Flink JobManager is accessible..."
for i in {1..30}; do
    if kubectl get service flink-session-cluster-rest -n flink-studio >/dev/null 2>&1; then
        print_status "Flink JobManager service is ready"
        break
    fi
    print_warning "Waiting for Flink JobManager service... (attempt $i/30)"
    sleep 10
done

# Step 4: Deploy Flink SQL Gateway
print_status "Step 4: Deploying Flink SQL Gateway..."
kubectl apply -f manifests/04-flink-sql-gateway.yaml

# Wait for SQL Gateway to be ready
kubectl wait --for=condition=Available deployment/flink-sql-gateway -n flink-studio --timeout=180s

# Step 5: Deploy Hue configuration and application
print_status "Step 5: Deploying Apache Hue..."
kubectl apply -f manifests/07-hue-config.yaml
kubectl apply -f manifests/08-hue.yaml

# Wait for Hue to be ready
kubectl wait --for=condition=Available deployment/hue -n flink-studio --timeout=300s

# Step 6: Apply security policies (optional)
print_status "Step 6: Applying Network Policies..."
kubectl apply -f manifests/06-network-policies.yaml

print_status "Deployment completed successfully!"
print_status ""
print_status "=== Access Information ==="
print_status "Flink UI: kubectl port-forward svc/flink-session-cluster-rest 8081:8081 -n flink-studio"
print_status "Hue UI: kubectl port-forward svc/hue 8888:8888 -n flink-studio"
print_status "SQL Gateway: kubectl port-forward svc/flink-sql-gateway 8083:8083 -n flink-studio"
print_status ""
print_status "Default Hue credentials: admin/admin"
print_status ""

# Cloud-specific information
if [ "$CLOUD_PROVIDER" = "gcp" ]; then
    print_status "=== GCP-Specific Configuration ==="
    print_status "Storage: gs://sbx-stag-flink-storage"
    print_status "Authentication: Service Account JSON Key"
    print_status ""
    print_status "Service Account Details:"
    print_status "- Google Service Account: flink-gcs@sbx-stag.iam.gserviceaccount.com"
    print_status "- Kubernetes Secret: gcp-service-account-key"
    print_status "- Key File: gcp-service-account-key.json"
    print_status ""
    print_warning "Security Note:"
    print_warning "- The service account key file 'gcp-service-account-key.json' has been created"
    print_warning "- This file contains sensitive credentials - keep it secure"
    print_warning "- Consider rotating the key periodically for better security"
    print_warning ""
    print_status "To verify GCS access from a pod:"
    print_status "kubectl exec -it deployment/flink-session-cluster -n flink-studio -- gsutil ls gs://sbx-stag-flink-storage/"
    print_status ""
    print_status "To run comprehensive authentication verification:"
    print_status "kubectl exec -it deployment/flink-session-cluster -n flink-studio -- /opt/flink/bin/verify-gcp-auth.sh"
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
print_status "and update your /etc/hosts file or DNS to point hue.flink-studio.local to your ingress IP"
