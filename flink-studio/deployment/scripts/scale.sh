#!/bin/bash

# Flink Session Cluster Scaling Script
# Usage: ./scale.sh [replicas] [environment]
# Example: ./scale.sh 6 gcp

set -e

# Default values
DEFAULT_REPLICAS=4
DEFAULT_ENV="gcp"
NAMESPACE="flink-studio"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Help function
show_help() {
    echo -e "${BLUE}Flink Session Cluster Scaling Script${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS] <replicas> [environment]"
    echo ""
    echo "Arguments:"
    echo "  replicas      Number of TaskManager replicas (default: $DEFAULT_REPLICAS)"
    echo "  environment   Environment (gcp|aks) (default: $DEFAULT_ENV)"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo "  -s, --status  Show current scaling status"
    echo "  -d, --dry-run Show what would be changed without applying"
    echo ""
    echo "Safety Features:"
    echo "  • Kubernetes context verification and confirmation"
    echo "  • Resource requirement validation against quotas"
    echo "  • Interactive confirmation before applying changes"
    echo "  • Dry-run mode to preview all changes safely"
    echo ""
    echo "Examples:"
    echo "  $0 6          # Scale to 6 replicas (GCP)"
    echo "  $0 8 aks      # Scale to 8 replicas (AKS)"
    echo "  $0 --status   # Show current status"
    echo "  $0 --dry-run 6 # Show changes without applying"
}

# Status function
show_status() {
    # Check context first (but don't ask for confirmation)
    check_kubernetes_context "--status-only"
    
    echo -e "${BLUE}Current Flink Cluster Status:${NC}"
    echo ""
    
    # Get current replicas from the deployment
    CURRENT_REPLICAS=$(kubectl get flinkdeployment flink-session-cluster -n $NAMESPACE -o jsonpath='{.spec.taskManager.replicas}' 2>/dev/null || echo "N/A")
    SLOTS_PER_TM=$(kubectl get flinkdeployment flink-session-cluster -n $NAMESPACE -o jsonpath='{.spec.flinkConfiguration.taskmanager\.numberOfTaskSlots}' 2>/dev/null || echo "N/A")
    
    if [[ "$CURRENT_REPLICAS" != "N/A" && "$SLOTS_PER_TM" != "N/A" ]]; then
        TOTAL_SLOTS=$((CURRENT_REPLICAS * SLOTS_PER_TM))
        echo -e "TaskManager Replicas: ${GREEN}$CURRENT_REPLICAS${NC}"
        echo -e "Slots per TaskManager: ${GREEN}$SLOTS_PER_TM${NC}"
        echo -e "Total Available Slots: ${GREEN}$TOTAL_SLOTS${NC}"
    else
        echo -e "${RED}FlinkDeployment not found or not accessible${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${BLUE}TaskManager Pods:${NC}"
    kubectl get pods -n $NAMESPACE -l component=taskmanager --no-headers 2>/dev/null || echo "No TaskManager pods found"
    
    echo ""
    echo -e "${BLUE}Resource Usage:${NC}"
    kubectl get resourcequota flink-studio-quota -n $NAMESPACE 2>/dev/null || echo "No resource quota found"
}

# Validate inputs
validate_inputs() {
    local replicas=$1
    local env=$2
    
    # Validate replicas is a number
    if ! [[ "$replicas" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Replicas must be a positive integer${NC}"
        exit 1
    fi
    
    # Validate replicas range
    if [[ $replicas -lt 1 || $replicas -gt 20 ]]; then
        echo -e "${RED}Error: Replicas must be between 1 and 20${NC}"
        exit 1
    fi
    
    # Validate environment
    if [[ "$env" != "gcp" && "$env" != "aks" ]]; then
        echo -e "${RED}Error: Environment must be 'gcp' or 'aks'${NC}"
        exit 1
    fi
}

# Calculate resource requirements
calculate_resources() {
    local replicas=$1
    local memory_per_tm=8  # 8Gi per TaskManager
    local cpu_per_tm=2     # 2 CPUs per TaskManager
    local jm_memory=2      # ~2Gi for JobManager
    local jm_cpu=1         # 1 CPU for JobManager
    
    local total_memory=$((replicas * memory_per_tm + jm_memory))
    local total_cpu=$((replicas * cpu_per_tm + jm_cpu))
    
    echo -e "${BLUE}Resource Requirements:${NC}"
    echo -e "TaskManagers: ${GREEN}$replicas${NC} × 8Gi/2CPU = ${GREEN}$((replicas * memory_per_tm))Gi${NC} / ${GREEN}$((replicas * cpu_per_tm))CPU${NC}"
    echo -e "JobManager: ${GREEN}${jm_memory}Gi${NC} / ${GREEN}${jm_cpu}CPU${NC}"
    echo -e "Total: ${GREEN}${total_memory}Gi${NC} / ${GREEN}${total_cpu}CPU${NC}"
    echo ""
    
    # Check against quota (assuming 48Gi/16CPU quota)
    if [[ $total_memory -gt 48 ]]; then
        echo -e "${YELLOW}Warning: Memory requirement (${total_memory}Gi) may exceed quota (48Gi)${NC}"
    fi
    if [[ $total_cpu -gt 16 ]]; then
        echo -e "${YELLOW}Warning: CPU requirement (${total_cpu}) may exceed quota (16)${NC}"
    fi
}

# Scale function
scale_cluster() {
    local replicas=$1
    local env=$2
    local dry_run=$3
    
    local manifest_file="manifests/03-flink-session-cluster-${env}.yaml"
    
    # Check if manifest file exists
    if [[ ! -f "$manifest_file" ]]; then
        echo -e "${RED}Error: Manifest file '$manifest_file' not found${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Scaling Flink TaskManager replicas to: ${GREEN}$replicas${NC}"
    echo -e "${BLUE}Environment: ${GREEN}$env${NC}"
    echo -e "${BLUE}Manifest: ${GREEN}$manifest_file${NC}"
    echo ""
    
    # Calculate and show resource requirements
    calculate_resources $replicas
    
    if [[ "$dry_run" == "true" ]]; then
        echo -e "${YELLOW}DRY RUN: Would update replicas in $manifest_file${NC}"
        echo -e "${YELLOW}DRY RUN: Would apply the updated manifest${NC}"
        return 0
    fi
    
    # Ask for confirmation
    read -p "Do you want to proceed? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Scaling cancelled${NC}"
        exit 0
    fi
    
    # Update the manifest file
    echo -e "${BLUE}Updating manifest file...${NC}"
    
    # Use sed to update the replicas value
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/replicas: [0-9]\+/replicas: $replicas/" "$manifest_file"
    else
        # Linux
        sed -i "s/replicas: [0-9]\+/replicas: $replicas/" "$manifest_file"
    fi
    
    # Apply the updated manifest
    echo -e "${BLUE}Applying updated manifest...${NC}"
    kubectl apply -f "$manifest_file"
    
    echo ""
    echo -e "${GREEN}Scaling initiated successfully!${NC}"
    echo -e "${BLUE}Monitor the scaling progress with:${NC}"
    echo "  kubectl get pods -n $NAMESPACE -l component=taskmanager -w"
    echo ""
    echo -e "${BLUE}Check cluster status with:${NC}"
    echo "  $0 --status"
}

# Check Kubernetes context
check_kubernetes_context() {
    echo -e "${BLUE}Checking Kubernetes context...${NC}"
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}Error: kubectl is not installed or not in PATH${NC}"
        exit 1
    fi
    
    # Get current context
    local current_context
    current_context=$(kubectl config current-context 2>/dev/null)
    
    if [[ $? -ne 0 || -z "$current_context" ]]; then
        echo -e "${RED}Error: No Kubernetes context is set${NC}"
        echo -e "${YELLOW}Available contexts:${NC}"
        kubectl config get-contexts --no-headers 2>/dev/null || echo "No contexts found"
        echo ""
        echo -e "${BLUE}Set a context with:${NC} kubectl config use-context <context-name>"
        exit 1
    fi
    
    # Get cluster info
    local cluster_info
    cluster_info=$(kubectl config view --minify --output jsonpath='{.clusters[0].cluster.server}' 2>/dev/null)
    
    echo -e "${GREEN}✓ Current Context:${NC} $current_context"
    echo -e "${GREEN}✓ Cluster Server:${NC} $cluster_info"
    
    # Test connectivity
    if ! kubectl cluster-info &>/dev/null; then
        echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
        echo -e "${YELLOW}Check your kubeconfig and cluster connectivity${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Cluster connectivity verified${NC}"
    
    # Check if namespace exists
    if ! kubectl get namespace $NAMESPACE &>/dev/null; then
        echo -e "${RED}Error: Namespace '$NAMESPACE' does not exist${NC}"
        echo -e "${YELLOW}Available namespaces:${NC}"
        kubectl get namespaces --no-headers 2>/dev/null | awk '{print "  " $1}' || echo "Cannot list namespaces"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Namespace '$NAMESPACE' exists${NC}"
    echo ""
    
    # Ask for context confirmation (except for status-only operations)
    if [[ "${1:-}" != "--status-only" ]]; then
        echo -e "${YELLOW}⚠️  You are about to perform operations on:${NC}"
        echo -e "   Context: ${GREEN}$current_context${NC}"
        echo -e "   Cluster: ${GREEN}$cluster_info${NC}"
        echo -e "   Namespace: ${GREEN}$NAMESPACE${NC}"
        echo ""
        
        read -p "Are you sure you want to proceed with this context? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Operation cancelled by user${NC}"
            echo -e "${BLUE}To switch context, use:${NC} kubectl config use-context <context-name>"
            exit 0
        fi
        echo -e "${GREEN}✓ Context confirmed by user${NC}"
        echo ""
    fi
}

# Main script logic
main() {
    local replicas=""
    local env="$DEFAULT_ENV"
    local dry_run="false"
    
    # Always check Kubernetes context first (except for help)
    local skip_context_check="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -s|--status)
                skip_context_check="false" # Still check context for status
                show_status
                exit 0
                ;;
            -d|--dry-run)
                dry_run="true"
                shift
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
            *)
                if [[ -z "$replicas" ]]; then
                    replicas=$1
                elif [[ -z "$env" || "$env" == "$DEFAULT_ENV" ]]; then
                    env=$1
                else
                    echo -e "${RED}Too many arguments${NC}"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Check Kubernetes context (unless showing help)
    if [[ "$skip_context_check" == "false" ]]; then
        check_kubernetes_context
    fi
    
    # If no replicas specified and not status/help, show help
    if [[ -z "$replicas" ]]; then
        show_help
        exit 1
    fi
    
    # Validate inputs
    validate_inputs "$replicas" "$env"
    
    # Scale the cluster
    scale_cluster "$replicas" "$env" "$dry_run"
}

# Run main function
main "$@"
