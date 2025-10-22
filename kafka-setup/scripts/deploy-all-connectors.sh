#!/bin/bash

set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "${SCRIPT_DIR}/common.sh"

# Function to display usage
usage() {
    cat << EOF
Usage: $0 --env <environment-file> [OPTIONS]

Deploy/Update all Debezium PostgreSQL connectors at once

REQUIRED:
    --env <file>       Environment configuration file (e.g., .sbx-uat.env)

OPTIONS:
    --dry-run          Show configuration without deploying
    --skip <connector> Skip specific connector (can be used multiple times)
                       Options: backbone, encarta, wms, tms
    -h, --help         Show this help message

EXAMPLES:
    $0 --env .sbx-uat.env
    $0 --env .production.env --dry-run
    $0 --env .sbx-uat.env --skip encarta
    $0 --env .sbx-uat.env --skip backbone --skip wms
    $0 --env .sbx-prod.env --skip tms

EOF
}

# Parse command line arguments
ENV_FILE=""
DRY_RUN=false
SKIP_CONNECTORS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            ENV_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip)
            SKIP_CONNECTORS+=("$2")
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

# Validate environment file
if [ -z "$ENV_FILE" ]; then
    print_error "Environment file is required"
    usage
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    print_error "Environment file not found: $ENV_FILE"
    exit 1
fi

# Function to check if connector should be skipped
should_skip() {
    local connector="$1"
    for skip in "${SKIP_CONNECTORS[@]}"; do
        if [ "$skip" = "$connector" ]; then
            return 0
        fi
    done
    return 1
}

# Deploy connectors
print_info "========================================"
print_info "Deploying all Debezium connectors"
print_info "Environment: $ENV_FILE"
if [ "$DRY_RUN" = true ]; then
    print_warning "DRY RUN MODE - No actual deployment"
fi
if [ ${#SKIP_CONNECTORS[@]} -gt 0 ]; then
    print_warning "Skipping: ${SKIP_CONNECTORS[*]}"
fi
print_info "========================================"
echo

# Array of connectors to deploy
CONNECTORS=("backbone" "encarta" "wms" "tms")
FAILED_CONNECTORS=()
DEPLOYED_CONNECTORS=()

for connector in "${CONNECTORS[@]}"; do
    if should_skip "$connector"; then
        print_warning "⏭️  Skipping $connector connector"
        echo
        continue
    fi
    
    print_info "🚀 Deploying $connector connector..."
    
    SCRIPT_PATH="${SCRIPT_DIR}/${connector}-debezium-postgres.sh"
    
    if [ ! -f "$SCRIPT_PATH" ]; then
        print_error "Script not found: $SCRIPT_PATH"
        FAILED_CONNECTORS+=("$connector")
        continue
    fi
    
    # Build command
    CMD="$SCRIPT_PATH --env $ENV_FILE"
    if [ "$DRY_RUN" = true ]; then
        CMD="$CMD --dry-run"
    fi
    
    # Execute the script
    if $CMD; then
        DEPLOYED_CONNECTORS+=("$connector")
        print_success "✅ $connector connector deployed successfully"
    else
        FAILED_CONNECTORS+=("$connector")
        print_error "❌ Failed to deploy $connector connector"
    fi
    
    echo
    print_info "----------------------------------------"
    echo
done

# Summary
print_info "========================================"
print_info "Deployment Summary"
print_info "========================================"

if [ ${#DEPLOYED_CONNECTORS[@]} -gt 0 ]; then
    print_success "Successfully deployed: ${DEPLOYED_CONNECTORS[*]}"
fi

if [ ${#SKIP_CONNECTORS[@]} -gt 0 ]; then
    print_warning "Skipped: ${SKIP_CONNECTORS[*]}"
fi

if [ ${#FAILED_CONNECTORS[@]} -gt 0 ]; then
    print_error "Failed: ${FAILED_CONNECTORS[*]}"
    exit 1
else
    if [ ${#DEPLOYED_CONNECTORS[@]} -gt 0 ]; then
        print_success "All requested connectors deployed successfully!"
    fi
fi

echo
print_info "Use the following commands to manage the connectors:"
echo "  # Check all connector statuses"
echo "  kubectl port-forward -n kafka svc/strimzi-kafka-connect-api 8083:8083 &"
echo "  curl -s localhost:8083/connectors | jq ."
echo ""
echo "  # Trigger snapshots for specific tables"
echo "  ${SCRIPT_DIR}/trigger-snapshots.sh --env $ENV_FILE -c <connector> -t <table>"
echo ""
echo "  # Manage topics"
echo "  ${SCRIPT_DIR}/manage-topics.sh --env $ENV_FILE --list"