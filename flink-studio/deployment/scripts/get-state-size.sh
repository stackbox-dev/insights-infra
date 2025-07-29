#!/bin/bash

# Flink State Size Monitoring Script
# This script provides comprehensive state size information for Flink deployments

set -e

# Configuration
NAMESPACE="flink-studio"
GCS_BUCKET="gs://sbx-stag-flink-storage"
FLINK_CLUSTER="flink-session-cluster"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}====== $1 ======${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

format_bytes() {
    local bytes=$1
    if [ $bytes -gt 1073741824 ]; then
        echo "$(( bytes / 1073741824 ))GB"
    elif [ $bytes -gt 1048576 ]; then
        echo "$(( bytes / 1048576 ))MB"
    elif [ $bytes -gt 1024 ]; then
        echo "$(( bytes / 1024 ))KB"
    else
        echo "${bytes}B"
    fi
}

# Main monitoring functions
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    print_success "kubectl found"
    
    # Check gsutil
    if ! command -v gsutil &> /dev/null; then
        print_error "gsutil not found. Please install Google Cloud SDK."
        exit 1
    fi
    print_success "gsutil found"
    
    # Check namespace exists
    if ! kubectl get namespace $NAMESPACE &> /dev/null; then
        print_error "Namespace '$NAMESPACE' not found"
        exit 1
    fi
    print_success "Namespace '$NAMESPACE' accessible"
}

check_emptydir_usage() {
    print_header "EmptyDir Volume Usage"
    
    # Since we're using emptyDir volumes, show the volume configuration from pods
    local tm_pods=$(kubectl get pods -n $NAMESPACE -l component=taskmanager -o name 2>/dev/null || echo "")
    
    if [ -z "$tm_pods" ]; then
        print_warning "No TaskManager pods found"
        return
    fi
    
    echo "EmptyDir volume configuration (50Gi limit per TaskManager):"
    for pod in $tm_pods; do
        local pod_name=$(basename $pod)
        echo "  $pod_name: Using emptyDir with 50Gi limit"
    done
    
    echo ""
    print_success "EmptyDir volume status retrieved"
}

check_pod_storage_usage() {
    print_header "Pod Storage Usage"
    
    # Get TaskManager pods
    local tm_pods=$(kubectl get pods -n $NAMESPACE -l component=taskmanager -o name 2>/dev/null || echo "")
    
    if [ -z "$tm_pods" ]; then
        print_warning "No TaskManager pods found"
        return
    fi
    
    echo "RocksDB Storage Usage per TaskManager:"
    for pod in $tm_pods; do
        local pod_name=$(basename $pod)
        echo -n "  $pod_name: "
        
        # Check RocksDB directory usage
        local usage=$(kubectl exec -n $NAMESPACE $pod_name -- du -sh /data/flink-rocksdb 2>/dev/null | cut -f1 2>/dev/null || echo "N/A")
        if [ "$usage" != "N/A" ]; then
            echo -e "${GREEN}$usage${NC}"
        else
            echo -e "${YELLOW}Unable to access${NC}"
        fi
    done
    
    echo ""
    echo "Total Pod Disk Usage:"
    for pod in $tm_pods; do
        local pod_name=$(basename $pod)
        echo -n "  $pod_name: "
        
        # Get overall disk usage
        local total_usage=$(kubectl exec -n $NAMESPACE $pod_name -- df -h / 2>/dev/null | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}' 2>/dev/null || echo "N/A")
        if [ "$total_usage" != "N/A" ]; then
            echo -e "${GREEN}$total_usage${NC}"
        else
            echo -e "${YELLOW}Unable to get disk info${NC}"
        fi
    done
}

check_gcs_state_size() {
    print_header "Google Cloud Storage State Size"
    
    echo "Checking GCS bucket contents..."
    
    # Check checkpoints
    echo -n "Checkpoints: "
    local checkpoint_size=$(gsutil du -sh ${GCS_BUCKET}/flink-checkpoints/ 2>/dev/null | cut -f1 || echo "0")
    if [ "$checkpoint_size" != "0" ]; then
        echo -e "${GREEN}$checkpoint_size${NC}"
    else
        echo -e "${YELLOW}No data or access denied${NC}"
    fi
    
    # Check changelog
    echo -n "Changelog: "
    local changelog_size=$(gsutil du -sh ${GCS_BUCKET}/changelog/ 2>/dev/null | cut -f1 || echo "0")
    if [ "$changelog_size" != "0" ]; then
        echo -e "${GREEN}$changelog_size${NC}"
    else
        echo -e "${YELLOW}No data or access denied${NC}"
    fi
    
    # Check savepoints
    echo -n "Savepoints: "
    local savepoint_size=$(gsutil du -sh ${GCS_BUCKET}/savepoints/ 2>/dev/null | cut -f1 || echo "0")
    if [ "$savepoint_size" != "0" ]; then
        echo -e "${GREEN}$savepoint_size${NC}"
    else
        echo -e "${YELLOW}No data or access denied${NC}"
    fi
    
    # Check archived jobs
    echo -n "Archived Jobs: "
    local archive_size=$(gsutil du -sh ${GCS_BUCKET}/archived-jobs/ 2>/dev/null | cut -f1 || echo "0")
    if [ "$archive_size" != "0" ]; then
        echo -e "${GREEN}$archive_size${NC}"
    else
        echo -e "${YELLOW}No data or access denied${NC}"
    fi
    
    # Total size
    echo -n "Total GCS Usage: "
    local total_size=$(gsutil du -sh ${GCS_BUCKET}/ 2>/dev/null | cut -f1 || echo "0")
    if [ "$total_size" != "0" ]; then
        echo -e "${BLUE}$total_size${NC}"
    else
        echo -e "${YELLOW}Unable to calculate total${NC}"
    fi
}

check_recent_checkpoints() {
    print_header "Recent Checkpoints"
    
    echo "Last 5 checkpoint directories:"
    gsutil ls -l ${GCS_BUCKET}/flink-checkpoints/ 2>/dev/null | tail -6 | head -5 || {
        print_warning "Unable to list recent checkpoints"
        return
    }
}

check_memory_usage() {
    print_header "Pod Memory Usage"
    
    echo "Current memory usage (requires metrics-server):"
    kubectl top pods -n $NAMESPACE 2>/dev/null || {
        print_warning "Metrics server not available - cannot show memory usage"
        return
    }
}

check_flink_jobs() {
    print_header "Active Flink Jobs"
    
    # Try to get Flink jobs via port-forward (if running)
    local job_manager_pod=$(kubectl get pods -n $NAMESPACE -l component=jobmanager -o name 2>/dev/null | head -1)
    
    if [ -z "$job_manager_pod" ]; then
        print_warning "No JobManager pod found"
        return
    fi
    
    local pod_name=$(basename $job_manager_pod)
    echo "JobManager pod: $pod_name"
    
    # Check if we can access Flink REST API (this would require port-forward)
    print_warning "To get job details, run: kubectl port-forward -n $NAMESPACE $pod_name 8081:8081"
    print_warning "Then visit: http://localhost:8081 for Flink Web UI"
}

show_recommendations() {
    print_header "Recommendations"
    
    echo "State Size Guidelines:"
    echo "  • Per task slot: < 25GB (current emptyDir: 50GB ÷ 2 slots)"
    echo "  • Total cluster: < 200GB (current: 4 TaskManagers × 50GB emptyDir)"
    echo "  • Memory per slot: ~3GB RocksDB + heap"
    echo ""
    echo "Scale up if:"
    echo "  • RocksDB usage > 20GB per TaskManager"
    echo "  • Checkpoint times > 5 minutes"
    echo "  • Memory usage consistently > 80%"
    echo "  • EmptyDir volume usage > 40GB per TaskManager"
    echo ""
    echo "Monitoring commands:"
    echo "  • Watch this script: watch -n 30 '$0'"
    echo "  • Flink Web UI: kubectl port-forward -n $NAMESPACE svc/$FLINK_CLUSTER 8081:80"
    echo "  • Logs: kubectl logs -n $NAMESPACE -l component=taskmanager -f"
}

# Main execution
main() {
    echo -e "${BLUE}Flink State Size Monitor${NC}"
    echo "Timestamp: $(date)"
    echo "Namespace: $NAMESPACE"
    echo "GCS Bucket: $GCS_BUCKET"
    
    check_prerequisites
    check_emptydir_usage
    check_pod_storage_usage
    check_gcs_state_size
    check_recent_checkpoints
    check_memory_usage
    check_flink_jobs
    show_recommendations
    
    print_success "State size check completed!"
}

# Handle command line arguments
case "${1:-}" in
    -h|--help)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  -h, --help     Show this help message"
        echo "  --namespace    Override namespace (default: $NAMESPACE)"
        echo "  --bucket       Override GCS bucket (default: $GCS_BUCKET)"
        echo ""
        echo "Examples:"
        echo "  $0                                    # Run full check"
        echo "  $0 --namespace my-flink              # Use different namespace"
        echo "  watch -n 30 '$0'                     # Monitor every 30 seconds"
        exit 0
        ;;
    --namespace)
        NAMESPACE="$2"
        shift 2
        ;;
    --bucket)
        GCS_BUCKET="$2"
        shift 2
        ;;
esac

# Run main function
main "$@"
