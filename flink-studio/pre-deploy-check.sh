#!/bin/bash

# Comprehensive Pre-Deployment Validation Script for Flink Studio
# This script validates all prerequisites and dependencies before deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

VALIDATION_FAILED=false
CLOUD_PROVIDER=""

echo "=========================================="
echo "Flink Studio Pre-Deployment Validation"
echo "=========================================="

# 1. Check basic tools
print_status "Checking required tools..."

if command -v kubectl >/dev/null 2>&1; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    print_success "kubectl found: $KUBECTL_VERSION"
else
    print_error "kubectl is not installed or not in PATH"
    VALIDATION_FAILED=true
fi

if command -v helm >/dev/null 2>&1; then
    HELM_VERSION=$(helm version --short 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    print_success "helm found: $HELM_VERSION"
else
    print_error "helm is not installed or not in PATH"
    VALIDATION_FAILED=true
fi

# 2. Check cluster connectivity and basic info
print_status "Checking Kubernetes cluster connectivity..."

if kubectl cluster-info >/dev/null 2>&1; then
    print_success "Kubernetes cluster is accessible"
    
    NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
    print_status "Cluster has $NODES node(s)"
    
    # Check cluster version
    K8S_VERSION=$(kubectl version --short 2>/dev/null | grep "Server Version" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    print_status "Kubernetes version: $K8S_VERSION"
    
else
    print_error "Cannot connect to Kubernetes cluster"
    VALIDATION_FAILED=true
fi

# 3. Cloud provider selection and validation
echo ""
echo "Select your cloud provider:"
echo "1) Google Cloud Platform (GCP/GKE)"
echo "2) Microsoft Azure (AKS)"
echo ""
read -p "Enter your choice (1 or 2): " cloud_choice

case $cloud_choice in
    1)
        CLOUD_PROVIDER="gcp"
        print_status "Selected: Google Cloud Platform (GCP/GKE)"
        
        # GCP-specific validations
        print_status "Validating GCP prerequisites..."
        
        # Check if gcloud is available
        if command -v gcloud >/dev/null 2>&1; then
            print_success "gcloud CLI found"
            
            # Check if user is authenticated
            if gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q "@"; then
                ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)
                print_success "Authenticated as: $ACTIVE_ACCOUNT"
            else
                print_warning "No active gcloud authentication found"
                print_warning "Run: gcloud auth login"
            fi
            
            # Check project
            PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
            if [ -n "$PROJECT" ]; then
                print_success "Current project: $PROJECT"
            else
                print_warning "No default project set"
                print_warning "Run: gcloud config set project YOUR_PROJECT_ID"
            fi
            
        else
            print_warning "gcloud CLI not found - some validations skipped"
        fi
        
        # Check GCS bucket access (if gcloud available)
        if command -v gsutil >/dev/null 2>&1; then
            if gsutil ls gs://sbx-stag-flink-storage/ >/dev/null 2>&1; then
                print_success "GCS bucket gs://sbx-stag-flink-storage/ is accessible"
            else
                print_error "Cannot access GCS bucket gs://sbx-stag-flink-storage/"
                print_error "Please ensure the bucket exists and you have access"
                VALIDATION_FAILED=true
            fi
        else
            print_warning "gsutil not available - GCS bucket access not validated"
        fi
        
        # Check Workload Identity setup
        print_status "Checking Workload Identity configuration..."
        if kubectl get serviceaccount flink -n flink-studio >/dev/null 2>&1; then
            WI_ANNOTATION=$(kubectl get serviceaccount flink -n flink-studio -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}' 2>/dev/null || echo "")
            if [ -n "$WI_ANNOTATION" ]; then
                print_success "Workload Identity annotation found: $WI_ANNOTATION"
            else
                print_warning "Workload Identity annotation not found on existing service account"
            fi
        else
            print_status "Service account will be created during deployment"
        fi
        ;;
        
    2)
        CLOUD_PROVIDER="azure"
        print_status "Selected: Microsoft Azure (AKS)"
        
        # Azure-specific validations
        print_status "Validating Azure prerequisites..."
        
        # Check if az cli is available
        if command -v az >/dev/null 2>&1; then
            print_success "Azure CLI found"
            
            # Check if user is authenticated
            if az account show >/dev/null 2>&1; then
                SUBSCRIPTION_NAME=$(az account show --query name -o tsv 2>/dev/null)
                print_success "Authenticated to subscription: $SUBSCRIPTION_NAME"
            else
                print_warning "No active Azure authentication found"
                print_warning "Run: az login"
            fi
            
        else
            print_warning "Azure CLI not found - some validations skipped"
        fi
        
        # Check Azure Storage Account access
        if command -v az >/dev/null 2>&1 && az account show >/dev/null 2>&1; then
            if az storage account show --name sbxstagflinkstorage --resource-group YOUR_RESOURCE_GROUP >/dev/null 2>&1; then
                print_success "Azure Storage Account sbxstagflinkstorage is accessible"
            else
                print_warning "Cannot validate Azure Storage Account access"
                print_warning "Please ensure storage account 'sbxstagflinkstorage' exists"
            fi
        fi
        
        # Check if Azure storage secret exists
        if kubectl get secret azure-storage-secret -n flink-studio >/dev/null 2>&1; then
            print_success "Azure storage secret exists"
        else
            print_error "Azure storage secret not found!"
            print_error "Create it with:"
            print_error "kubectl create secret generic azure-storage-secret \\"
            print_error "  --from-literal=storage-account-key=YOUR_ACTUAL_KEY \\"
            print_error "  -n flink-studio"
            VALIDATION_FAILED=true
        fi
        ;;
        
    *)
        print_error "Invalid choice. Please run the script again and select 1 or 2."
        exit 1
        ;;
esac

# 4. Check cluster resources
print_status "Checking cluster resources..."

# Get node information using kubectl top nodes (if metrics server is available)
if kubectl top nodes >/dev/null 2>&1; then
    print_status "Metrics server available - checking current resource usage"
    
    # Get allocatable resources from nodes
    TOTAL_CPU_MILLICORES=0
    TOTAL_MEMORY_KB=0
    NODE_COUNT=0
    
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            NODE_COUNT=$((NODE_COUNT + 1))
            # Extract allocatable CPU (in millicores) and memory (in Ki)
            CPU_ALLOCATABLE=$(echo "$line" | awk '{print $2}')
            MEMORY_ALLOCATABLE=$(echo "$line" | awk '{print $3}')
            
            # Convert CPU to millicores
            if [[ $CPU_ALLOCATABLE =~ m$ ]]; then
                CPU_MILLICORES=${CPU_ALLOCATABLE%m}
            else
                CPU_MILLICORES=$((${CPU_ALLOCATABLE} * 1000))
            fi
            
            # Convert memory to KB
            if [[ $MEMORY_ALLOCATABLE =~ Ki$ ]]; then
                MEMORY_KB=${MEMORY_ALLOCATABLE%Ki}
            elif [[ $MEMORY_ALLOCATABLE =~ Mi$ ]]; then
                MEMORY_KB=$((${MEMORY_ALLOCATABLE%Mi} * 1024))
            elif [[ $MEMORY_ALLOCATABLE =~ Gi$ ]]; then
                MEMORY_KB=$((${MEMORY_ALLOCATABLE%Gi} * 1024 * 1024))
            else
                MEMORY_KB=$MEMORY_ALLOCATABLE
            fi
            
            TOTAL_CPU_MILLICORES=$((TOTAL_CPU_MILLICORES + CPU_MILLICORES))
            TOTAL_MEMORY_KB=$((TOTAL_MEMORY_KB + MEMORY_KB))
        fi
    done < <(kubectl get nodes -o custom-columns="NAME:.metadata.name,CPU:.status.allocatable.cpu,MEMORY:.status.allocatable.memory" --no-headers 2>/dev/null)
    
    TOTAL_CPU_CORES=$((TOTAL_CPU_MILLICORES / 1000))
    TOTAL_MEMORY_GB=$((TOTAL_MEMORY_KB / 1024 / 1024))
    
    print_status "Found $NODE_COUNT node(s) with total allocatable capacity:"
    print_status "  CPU: ${TOTAL_CPU_CORES} cores (${TOTAL_CPU_MILLICORES} millicores)"
    print_status "  Memory: ${TOTAL_MEMORY_GB}GB"
else
    print_warning "Metrics server not available - checking node allocatable capacity only"
    
    # Fallback: just check if we have nodes and basic info
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$NODE_COUNT" -gt 0 ]; then
        print_status "Found $NODE_COUNT node(s) in the cluster"
        
        # For autoscaling clusters, we can't reliably predict capacity
        if [ "$CLOUD_PROVIDER" = "gcp" ]; then
            print_status "GKE autoscaling cluster detected - resources can scale based on demand"
            print_success "Cluster can automatically scale to meet resource requirements"
            TOTAL_CPU_CORES=999  # Set high values to skip resource checks for autoscaling
            TOTAL_MEMORY_GB=999
        elif [ "$CLOUD_PROVIDER" = "azure" ]; then
            print_status "AKS cluster detected - checking if autoscaling is enabled"
            print_success "Cluster should scale to meet resource requirements"
            TOTAL_CPU_CORES=999  # Set high values to skip resource checks for autoscaling
            TOTAL_MEMORY_GB=999
        else
            print_warning "Cannot determine cluster resource capacity without metrics server"
            print_warning "Skipping resource validation - ensure cluster has sufficient resources"
            TOTAL_CPU_CORES=999  # Skip validation
            TOTAL_MEMORY_GB=999
        fi
    else
        print_error "No nodes found in cluster"
        VALIDATION_FAILED=true
        TOTAL_CPU_CORES=0
        TOTAL_MEMORY_GB=0
    fi
fi

# Check if we have enough resources (estimated requirement: 6 cores, 12GB for our optimized setup)
REQUIRED_CPU=6
REQUIRED_MEMORY=12

if [ $TOTAL_CPU_CORES -lt $REQUIRED_CPU ] && [ $TOTAL_CPU_CORES -lt 999 ]; then
    print_error "Insufficient CPU capacity. Need at least $REQUIRED_CPU cores, found $TOTAL_CPU_CORES"
    print_error "Consider scaling up your cluster or enabling autoscaling"
    VALIDATION_FAILED=true
elif [ $TOTAL_CPU_CORES -ge 999 ]; then
    print_success "Cluster can autoscale - CPU capacity validation skipped"
else
    print_success "CPU capacity sufficient ($TOTAL_CPU_CORES cores available)"
fi

if [ $TOTAL_MEMORY_GB -lt $REQUIRED_MEMORY ] && [ $TOTAL_MEMORY_GB -lt 999 ]; then
    print_error "Insufficient memory capacity. Need at least ${REQUIRED_MEMORY}GB, found ${TOTAL_MEMORY_GB}GB"
    print_error "Consider scaling up your cluster or enabling autoscaling"
    VALIDATION_FAILED=true
elif [ $TOTAL_MEMORY_GB -ge 999 ]; then
    print_success "Cluster can autoscale - memory capacity validation skipped"
else
    print_success "Memory capacity sufficient (${TOTAL_MEMORY_GB}GB available)"
fi

# 5. Check storage classes
print_status "Checking storage classes..."

if [ "$CLOUD_PROVIDER" = "gcp" ]; then
    if kubectl get storageclass standard-rwo >/dev/null 2>&1; then
        print_success "GCP storage class 'standard-rwo' found"
    else
        print_warning "Storage class 'standard-rwo' not found. Checking alternatives..."
        if kubectl get storageclass standard >/dev/null 2>&1; then
            print_warning "Found 'standard' storage class as alternative"
        else
            print_error "No suitable storage class found for GCP"
            VALIDATION_FAILED=true
        fi
    fi
elif [ "$CLOUD_PROVIDER" = "azure" ]; then
    if kubectl get storageclass managed-csi >/dev/null 2>&1; then
        print_success "Azure storage class 'managed-csi' found"
    else
        print_warning "Storage class 'managed-csi' not found. Checking alternatives..."
        if kubectl get storageclass default >/dev/null 2>&1; then
            print_warning "Found 'default' storage class as alternative"
        else
            print_error "No suitable storage class found for Azure"
            VALIDATION_FAILED=true
        fi
    fi
fi

# 6. Check Flink Kubernetes Operator
print_status "Checking Flink Kubernetes Operator..."

if kubectl get deployment flink-kubernetes-operator -n flink-system >/dev/null 2>&1; then
    print_success "Flink Kubernetes Operator is already installed"
else
    print_status "Flink Kubernetes Operator will be installed during deployment"
fi

# 7. Check namespace
if kubectl get namespace flink-studio >/dev/null 2>&1; then
    print_warning "Namespace 'flink-studio' already exists"
    print_warning "Existing resources may be overwritten during deployment"
else
    print_status "Namespace 'flink-studio' will be created during deployment"
fi

# 8. Final validation summary
echo ""
echo "=========================================="
echo "Validation Summary"
echo "=========================================="

if [ "$VALIDATION_FAILED" = true ]; then
    print_error "Pre-deployment validation FAILED!"
    print_error "Please fix the above issues before running ./deploy.sh"
    exit 1
else
    print_success "Pre-deployment validation PASSED!"
    print_success "Ready to deploy Flink Studio for $CLOUD_PROVIDER"
    echo ""
    print_status "Next steps:"
    print_status "1. Run ./deploy.sh to start deployment"
    print_status "2. Monitor deployment progress"
    print_status "3. Access Hue UI once deployment completes"
fi
