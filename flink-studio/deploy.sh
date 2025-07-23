#!/bin/bash

# Flink Platform Deployment Script
# This script deploys the entire Flink platform according to the architecture

set -e

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

# Check if custom Docker image is required
if [ "$CLOUD_PROVIDER" = "gcp" ]; then
    print_warning "Make sure you have built and pushed the custom GCS-enabled Flink image:"
    print_warning "cd gcp && docker build -t asia-docker.pkg.dev/sbx-ci-cd/private/flink-gke:2.0.0-scala_2.12-java21 ."
    print_warning "cd gcp && docker push asia-docker.pkg.dev/sbx-ci-cd/private/flink-gke:2.0.0-scala_2.12-java21"
elif [ "$CLOUD_PROVIDER" = "azure" ]; then
    print_warning "Make sure you have built and pushed the custom Azure-enabled Flink image:"
    print_warning "cd azure && docker build -t sbxstag.azurecr.io/flink-gke:2.0.0-scala_2.12-azure ."
    print_warning "docker push sbxstag.azurecr.io/flink-gke:2.0.0-scala_2.12-azure"
fi
print_status ""

helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.14.0/
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

# Wait for Flink cluster to be ready
print_status "Waiting for Flink Session Cluster to be ready..."
kubectl wait --for=condition=Ready flinkdeployment/flink-session-cluster -n flink-studio --timeout=300s

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
    print_status "Authentication: GKE Workload Identity"
    print_status ""
    print_warning "Make sure you have:"
    print_warning "1. Created Google Service Account: flink-gcs@sbx-stag.iam.gserviceaccount.com"
    print_warning "2. Granted Storage Admin role on gs://sbx-stag-flink-storage bucket"
    print_warning "3. Enabled Workload Identity binding between Kubernetes and Google Service Accounts"
    print_warning ""
    print_status "Setup commands:"
    print_status "gcloud iam service-accounts create flink-gcs --project=sbx-stag"
    print_status "gsutil iam ch serviceAccount:flink-gcs@sbx-stag.iam.gserviceaccount.com:roles/storage.admin gs://sbx-stag-flink-storage"
    print_status "gcloud iam service-accounts add-iam-policy-binding \\"
    print_status "  --role roles/iam.workloadIdentityUser \\"
    print_status "  --member 'serviceAccount:sbx-stag.svc.id.goog[flink-studio/flink]' \\"
    print_status "  flink-gcs@sbx-stag.iam.gserviceaccount.com"
elif [ "$CLOUD_PROVIDER" = "azure" ]; then
    print_status "=== Azure-Specific Configuration ==="
    print_status "Storage: wasbs://flink@sbxstagflinkstorage.blob.core.windows.net"
    print_status "Authentication: Storage Account Key"
    print_status ""
    print_warning "Make sure you have:"
    print_warning "1. Created Azure Storage Account: sbxstagflinkstorage"
    print_warning "2. Created blob container: flink"
    print_warning "3. Updated the storage account key in manifests/02-rbac-aks.yaml"
    print_warning ""
    print_status "To update storage key:"
    print_status "echo -n 'YOUR_STORAGE_ACCOUNT_KEY' | base64"
    print_status "# Replace REPLACE_WITH_BASE64_ENCODED_STORAGE_KEY in 02-rbac-aks.yaml"
fi

print_status ""
print_status "To access via Ingress, ensure your ingress controller is properly configured"
print_status "and update your /etc/hosts file or DNS to point hue.flink-studio.local to your ingress IP"
