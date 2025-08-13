#!/bin/bash

set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/../manifests"

# Source common functions
source "${SCRIPT_DIR}/common.sh"

# Function to display usage
usage() {
    cat << EOF
Usage: $0 --env <environment> [OPTIONS]

Deploy Kubernetes manifests for Kafka setup

REQUIRED:
    --env <name>       Environment name (e.g., sbx-uat, production)
                       Must match a directory in manifests/

OPTIONS:
    --dry-run          Show what would be deployed without applying
    --namespace <ns>   Override namespace from manifest
    -h, --help         Show this help message

EXAMPLES:
    $0 --env sbx-uat
    $0 --env production --dry-run
    $0 --env sbx-uat --namespace custom-kafka

EOF
}

# Parse command line arguments
ENVIRONMENT=""
DRY_RUN=false
NAMESPACE_OVERRIDE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --namespace)
            NAMESPACE_OVERRIDE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$ENVIRONMENT" ]; then
    print_error "Environment is required"
    usage
    exit 1
fi

# Check if environment directory exists
ENV_DIR="${MANIFESTS_DIR}/${ENVIRONMENT}"
if [ ! -d "$ENV_DIR" ]; then
    print_error "Environment directory not found: $ENV_DIR"
    print_info "Available environments:"
    ls -1 "$MANIFESTS_DIR" 2>/dev/null | while read dir; do
        if [ -d "${MANIFESTS_DIR}/${dir}" ]; then
            echo "  - $dir"
        fi
    done
    exit 1
fi

# Find all YAML files in the environment directory
print_info "Finding manifests in: $ENV_DIR"
MANIFEST_FILES=($(find "$ENV_DIR" -name "*.yaml" -o -name "*.yml" | sort))

if [ ${#MANIFEST_FILES[@]} -eq 0 ]; then
    print_warning "No manifest files found in $ENV_DIR"
    exit 0
fi

print_info "Found ${#MANIFEST_FILES[@]} manifest file(s):"
for file in "${MANIFEST_FILES[@]}"; do
    echo "  - $(basename "$file")"
done
echo

# Check Kubernetes context
print_info "Current Kubernetes context:"
kubectl config current-context || {
    print_error "Failed to get current context. Is kubectl configured?"
    exit 1
}
echo

# Confirmation prompt
if [ "$DRY_RUN" = false ]; then
    print_warning "This will deploy manifests to the current Kubernetes cluster"
    read -p "Are you sure you want to continue? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_warning "Deployment cancelled"
        exit 0
    fi
    echo
fi

# Function to apply a manifest
apply_manifest() {
    local file="$1"
    local filename=$(basename "$file")
    
    print_info "Processing: $filename"
    
    # Build kubectl command
    local cmd="kubectl apply -f $file"
    
    # Add namespace override if specified
    if [ -n "$NAMESPACE_OVERRIDE" ]; then
        cmd="$cmd --namespace=$NAMESPACE_OVERRIDE"
    fi
    
    # Add dry-run flag if specified
    if [ "$DRY_RUN" = true ]; then
        cmd="$cmd --dry-run=client"
    fi
    
    # Execute the command
    if $cmd; then
        if [ "$DRY_RUN" = true ]; then
            print_success "✅ [DRY RUN] $filename would be applied successfully"
        else
            print_success "✅ $filename applied successfully"
        fi
        return 0
    else
        print_error "❌ Failed to apply $filename"
        return 1
    fi
}

# Deploy manifests
print_info "========================================"
if [ "$DRY_RUN" = true ]; then
    print_info "DRY RUN - Validating manifests"
else
    print_info "Deploying manifests"
fi
print_info "========================================"
echo

FAILED_MANIFESTS=()
DEPLOYED_MANIFESTS=()

for manifest in "${MANIFEST_FILES[@]}"; do
    if apply_manifest "$manifest"; then
        DEPLOYED_MANIFESTS+=("$(basename "$manifest")")
    else
        FAILED_MANIFESTS+=("$(basename "$manifest")")
        
        # Ask if should continue after failure
        if [ "$DRY_RUN" = false ]; then
            read -p "Continue with remaining manifests? (yes/no): " continue_deploy
            if [ "$continue_deploy" != "yes" ]; then
                print_warning "Deployment stopped by user"
                break
            fi
        fi
    fi
    echo
done

# Summary
print_info "========================================"
print_info "Deployment Summary"
print_info "========================================"

if [ ${#DEPLOYED_MANIFESTS[@]} -gt 0 ]; then
    print_success "Successfully deployed:"
    for manifest in "${DEPLOYED_MANIFESTS[@]}"; do
        echo "  ✅ $manifest"
    done
fi

if [ ${#FAILED_MANIFESTS[@]} -gt 0 ]; then
    print_error "Failed to deploy:"
    for manifest in "${FAILED_MANIFESTS[@]}"; do
        echo "  ❌ $manifest"
    done
    exit 1
fi

if [ "$DRY_RUN" = true ]; then
    echo
    print_warning "This was a dry run. No changes were made."
    print_info "Remove --dry-run flag to actually deploy the manifests."
else
    echo
    print_success "All manifests deployed successfully!"
    
    # Show useful commands
    echo
    print_info "Useful commands:"
    echo "  # Check deployment status"
    echo "  kubectl get all -n kafka"
    echo ""
    echo "  # Check Kafka Connect status"
    echo "  kubectl get pods -n kafka -l app=kafka-connect"
    echo ""
    echo "  # View logs"
    echo "  kubectl logs -n kafka -l app=kafka-connect --tail=100"
fi