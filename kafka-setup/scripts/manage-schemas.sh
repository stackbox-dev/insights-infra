#!/bin/bash

set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "${SCRIPT_DIR}/common.sh"

# Function to display usage
usage() {
    cat << EOF
Usage: $0 --env <environment-file> <command> [OPTIONS]

Manage schemas in Kafka Schema Registry

REQUIRED:
    --env <file>           Environment configuration file (e.g., .sbx-uat.env)

COMMANDS:
    list                   List all schemas in the registry
    delete                 Delete schemas from the registry

OPTIONS:
    --filter, -f PATTERN   Filter schemas by pattern (supports regex)
    --dry-run              (delete only) Show what would be deleted without actually deleting
    --force                (delete only) Skip confirmation prompt (use with caution!)
    -h, --help             Show this help message

EXAMPLES:
    # List all schemas
    $0 --env .sbx-uat.env list
    
    # List schemas matching a pattern
    $0 --env .sbx-uat.env list --filter "wms.*"
    
    # Delete schemas (dry-run)
    $0 --env .sbx-uat.env delete --filter "test-.*" --dry-run
    
    # Delete schemas (force)
    $0 --env .sbx-uat.env delete --filter "temp-.*" --force

SAFETY: Signal topic schemas (debezium-signals-*) are always protected from deletion

EOF
}

# Parse command line arguments
ENV_FILE=""
COMMAND=""
FILTER_PATTERN=""
DRY_RUN=false
FORCE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --env)
      ENV_FILE="$2"
      shift 2
      ;;
    list|delete)
      COMMAND="$1"
      shift
      ;;
    --filter|-f)
      FILTER_PATTERN="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --help|-h)
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
if [ -z "$ENV_FILE" ]; then
    print_error "Environment file is required"
    usage
    exit 1
fi

if [ -z "$COMMAND" ]; then
    print_error "Command is required (list or delete)"
    usage
    exit 1
fi

# Load environment and check Kubernetes context
if ! load_env_file "$ENV_FILE"; then
    exit 1
fi

if ! check_kubernetes_context; then
    exit 1
fi

if ! fetch_kubernetes_credentials; then
    exit 1
fi

# Find a pod to execute commands from
print_info "Finding Kafka Connect pod..."
CONNECT_POD=$(get_connect_pod)
if [ $? -ne 0 ]; then
    exit 1
fi

print_success "Using pod: $CONNECT_POD"

# Step 1: Get all schemas
print_info "Fetching schemas from registry..."

# Get list of all subjects from Schema Registry
all_schemas=$(execute_curl_in_pod "$CONNECT_POD" "GET" \
    "${SCHEMA_REGISTRY_URL}/subjects" \
    "" \
    "-H 'Accept: application/vnd.schemaregistry.v1+json'")

# Extract the body (remove HTTP status code)
schema_list=$(echo "$all_schemas" | sed '$d')

# Parse JSON array to get individual schemas
if [ -z "$schema_list" ] || [ "$schema_list" = "[]" ]; then
    print_warning "No schemas found in registry"
    exit 0
fi

# Convert JSON array to line-separated list
schema_names=$(echo "$schema_list" | jq -r '.[]' 2>/dev/null)

if [ -z "$schema_names" ]; then
    print_error "Failed to parse schema list"
    exit 1
fi

# Apply filters
filtered_schemas="$schema_names"

# Always protect signal schemas (only for delete command)
if [ "$COMMAND" = "delete" ]; then
  filtered_schemas=$(echo "$filtered_schemas" | grep -v '^debezium-signals-' 2>/dev/null || echo "$filtered_schemas")
fi

# Apply custom filter if provided
if [ -n "$FILTER_PATTERN" ]; then
  temp_filtered=$(echo "$filtered_schemas" | grep -E "$FILTER_PATTERN" 2>/dev/null)
  if [ $? -ne 0 ]; then
    print_error "Invalid filter pattern"
    exit 1
  fi
  filtered_schemas="$temp_filtered"
fi

# Sort schemas
schema_names=$(echo "$filtered_schemas" | sort)

# Validate output
if [ -z "$schema_names" ] || [ "$schema_names" == "" ]; then
  print_warning "No schemas found matching the criteria"
  if [ -n "$FILTER_PATTERN" ]; then
    echo "Filter applied: $FILTER_PATTERN"
  fi
  if [ "$COMMAND" = "delete" ]; then
    echo "Signal schemas (debezium-signals-*) are protected"
  fi
  exit 0
fi

# Count schemas
schema_count=$(echo "$schema_names" | wc -l | xargs)

# Handle list command
if [ "$COMMAND" = "list" ]; then
    print_info "Schemas in registry ($schema_count):"
    if [ -n "$FILTER_PATTERN" ]; then
      print_color $YELLOW "   Filter applied: $FILTER_PATTERN"
    fi
    echo ""
    
    # Display the list
    echo "$schema_names" | while read schema; do
        echo "  - $schema"
    done
    
    echo ""
    print_success "Total: $schema_count schemas"
    exit 0
fi

# Step 2: Display the schemas (for delete command)
print_info "Schemas to be deleted ($schema_count):"
if [ -n "$FILTER_PATTERN" ]; then
  print_color $YELLOW "   Filter applied: $FILTER_PATTERN"
fi
print_color $YELLOW "   Signal schemas (debezium-signals-*) are protected"
echo ""

# Display the list
echo "$schema_names" | while read schema; do
    echo "  - $schema"
done

# Step 3: Get confirmation (unless --force is used)
if [ "$FORCE" = false ] && [ "$DRY_RUN" = false ]; then
    echo ""
    print_color $YELLOW "⚠️  WARNING: This will permanently delete the above schemas from the registry"
    echo ""
    
    # First confirmation
    read -p "Are you sure you want to proceed? Type 'yes' to continue: " confirm1
    if [ "$confirm1" != "yes" ]; then
        print_warning "Operation cancelled"
        exit 0
    fi
    
    # Second confirmation with count
    echo ""
    read -p "Please type the number of schemas to delete ($schema_count) to confirm: " confirm2
    if [ "$confirm2" != "$schema_count" ]; then
        print_warning "Confirmation failed. Operation cancelled"
        exit 0
    fi
fi

# Step 4: Delete schemas
if [ "$DRY_RUN" = false ]; then
    print_info "Deleting schemas..."
    
    success_count=0
    fail_count=0
    
    for schema in $schema_names; do
        echo -n "Deleting schema: $schema ... "
        
        # First, soft delete the schema
        soft_delete_response=$(execute_curl_in_pod "$CONNECT_POD" "DELETE" \
            "${SCHEMA_REGISTRY_URL}/subjects/${schema}" \
            "" \
            "-H 'Accept: application/vnd.schemaregistry.v1+json'")
        
        soft_delete_status=$(echo "$soft_delete_response" | tail -n1)
        
        # Then permanently delete the schema
        if [ "$soft_delete_status" = "200" ] || [ "$soft_delete_status" = "204" ] || [ "$soft_delete_status" = "404" ]; then
            perm_delete_response=$(execute_curl_in_pod "$CONNECT_POD" "DELETE" \
                "${SCHEMA_REGISTRY_URL}/subjects/${schema}?permanent=true" \
                "" \
                "-H 'Accept: application/vnd.schemaregistry.v1+json'")
            
            perm_delete_status=$(echo "$perm_delete_response" | tail -n1)
            
            if [ "$perm_delete_status" = "200" ] || [ "$perm_delete_status" = "204" ]; then
                print_success "✅ Deleted"
                ((success_count++))
            else
                print_error "❌ Failed (HTTP $perm_delete_status)"
                ((fail_count++))
            fi
        else
            print_error "❌ Failed soft delete (HTTP $soft_delete_status)"
            ((fail_count++))
        fi
    done
    
    echo ""
    print_success "Deletion process completed"
    print_info "Successfully deleted: $success_count schemas"
    if [ $fail_count -gt 0 ]; then
        print_warning "Failed to delete: $fail_count schemas"
    fi
else
    print_color $YELLOW "\n[DRY RUN] No schemas were deleted"
fi