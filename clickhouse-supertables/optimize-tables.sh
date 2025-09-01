#!/bin/bash

# ClickHouse table optimization script using dev-pod
# This script connects to ClickHouse via dev-pod and runs OPTIMIZE TABLE FINAL on all tables

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="default"
ENV_FILE=".sbx-uat.env"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --filter)
            TABLE_FILTER="$2"
            shift 2
            ;;
        --env)
            ENV_FILE="$2"
            shift 2
            ;;
        --database)
            DATABASE_OVERRIDE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --filter <pattern>    Filter tables by name pattern (regex pattern)"
            echo "  --env <file>          Environment file (default: .sbx-uat.env)"
            echo "  --database <name>     Override database from env file"
            echo "  --dry-run            Show what would be optimized without running"
            echo "  --help               Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Optimize all tables"
            echo "  $0 --filter '^wms_'                  # Optimize tables starting with wms_"
            echo "  $0 --filter '.*inventory.*'          # Optimize tables containing 'inventory'"
            echo "  $0 --filter '^(wms|oms)_.*staging$'  # Optimize staging tables for wms/oms"
            echo "  $0 --env .prod.env                   # Use production environment"
            echo "  $0 --dry-run                         # Show tables that would be optimized"
            echo ""
            echo "IMPORTANT:"
            echo "  - Only optimizes regular tables (excludes views, materialized views, etc.)"
            echo "  - Uses OPTIMIZE TABLE <name> FINAL for complete optimization"
            echo "  - This operation can be resource intensive on large tables"
            echo "  - Filter uses regex patterns (grep -E compatible)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Load environment variables
if [ ! -f "$BASE_DIR/$ENV_FILE" ]; then
    echo -e "${RED}Error: Environment file $ENV_FILE not found${NC}"
    echo "Please create $ENV_FILE or specify a different file with --env"
    exit 1
fi

# Source the environment file
set -a
source "$BASE_DIR/$ENV_FILE"
set +a

# Use database override if provided, otherwise use env file value
DATABASE="${DATABASE_OVERRIDE:-${CLICKHOUSE_DATABASE:-sbx_uat}}"

# Validate required environment variables
if [ -z "$CLICKHOUSE_HOSTNAME" ] || [ -z "$CLICKHOUSE_NATIVE_PORT" ] || [ -z "$CLICKHOUSE_USER" ]; then
    echo -e "${RED}Error: Missing required ClickHouse configuration in $ENV_FILE${NC}"
    echo "Required variables: CLICKHOUSE_HOSTNAME, CLICKHOUSE_NATIVE_PORT, CLICKHOUSE_USER"
    exit 1
fi

echo -e "${GREEN}ClickHouse Table Optimization Script${NC}"
echo "===================================="
echo "Environment: $ENV_FILE"
echo "Host: $CLICKHOUSE_HOSTNAME:$CLICKHOUSE_NATIVE_PORT"
echo "Database: $DATABASE"
echo "User: $CLICKHOUSE_USER"
if [ -n "$TABLE_FILTER" ]; then
    echo "Filter: $TABLE_FILTER"
fi
echo "Dry Run: ${DRY_RUN:-false}"
echo ""

# Function to get ClickHouse password from Kubernetes secret
get_clickhouse_password() {
    echo "Fetching ClickHouse credentials from Kubernetes..."
    CLICKHOUSE_PASSWORD=$(kubectl get secret clickhouse-admin -n kafka -o jsonpath='{.data.password}' | base64 --decode)
    if [ -z "$CLICKHOUSE_PASSWORD" ]; then
        echo -e "${RED}Error: Could not fetch ClickHouse password from secret${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Credentials fetched successfully${NC}"
}

# Function to find dev-pod
find_dev_pod() {
    echo "Finding dev-pod in default namespace..."
    DEV_POD=$(kubectl get pods -n default | grep dev-pod | awk '{print $1}' | head -1)
    
    if [ -z "$DEV_POD" ]; then
        echo -e "${RED}Error: No dev-pod found in default namespace${NC}"
        echo "Please ensure dev-pod is running in the default namespace"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Using pod: $DEV_POD${NC}"
}

# Function to check clickhouse-client in dev-pod
setup_clickhouse_client() {
    echo "Checking clickhouse-client in dev-pod..."
    
    # Check if clickhouse-client is already installed
    if kubectl exec -n default $DEV_POD -- which clickhouse-client &>/dev/null; then
        echo -e "${GREEN}✓ clickhouse-client already installed${NC}"
    else
        echo -e "${RED}Error: clickhouse-client not installed in dev-pod${NC}"
        echo "Please install clickhouse-client in the dev-pod first"
        exit 1
    fi
}

# Function to execute ClickHouse query
execute_query() {
    local query="$1"
    local description="$2"
    
    if [ -n "$description" ]; then
        echo "  $description"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY RUN] Would execute: $query"
        return
    fi
    
    # Execute query with retry logic
    local max_retries=3
    local retry_count=0
    local success=false
    
    while [ $retry_count -lt $max_retries ] && [ "$success" = "false" ]; do
        if [ $retry_count -gt 0 ]; then
            echo "  Retrying (attempt $((retry_count + 1))/$max_retries)..."
            sleep 2
        fi
        
        # Execute with timeout and connection settings
        local cmd_output=""
        local cmd_exit_code=0
        
        # Run the command and capture output
        cmd_output=$(kubectl exec -n default $DEV_POD -- clickhouse-client \
            --host="$CLICKHOUSE_HOSTNAME" \
            --port="$CLICKHOUSE_NATIVE_PORT" \
            --user="$CLICKHOUSE_USER" \
            --password="$CLICKHOUSE_PASSWORD" \
            --database="$DATABASE" \
            --secure \
            --connect_timeout=30 \
            --receive_timeout=600 \
            --send_timeout=300 \
            --query="$query" 2>&1) || cmd_exit_code=$?
        
        # Display the output with appropriate coloring
        if [ -n "$cmd_output" ]; then
            echo "$cmd_output" | while IFS= read -r line; do
                if [[ $line == *"Error"* ]] || [[ $line == *"Exception"* ]] || [[ $line == *"FAILED"* ]]; then
                    echo -e "  ${RED}$line${NC}"
                elif [[ $line == *"OPTIMIZE"* ]] || [[ $line == *"Ok."* ]]; then
                    echo -e "  ${GREEN}$line${NC}"
                elif [[ $line == *"rows in set"* ]] || [[ $line == *"Elapsed:"* ]]; then
                    echo -e "  ${YELLOW}$line${NC}"
                else
                    echo "  $line"
                fi
            done
        fi
        
        if [ $cmd_exit_code -eq 0 ]; then
            success=true
            echo -e "  ${GREEN}✓ Query executed successfully${NC}"
        else
            echo -e "  ${RED}✗ Query failed with exit code $cmd_exit_code${NC}"
            retry_count=$((retry_count + 1))
        fi
    done
    
    if [ "$success" = "false" ]; then
        echo -e "  ${RED}✗ Failed after $max_retries attempts${NC}"
        return 1
    fi
    
    return 0
}

# Function to get list of tables to optimize
get_tables_to_optimize() {
    local query="SELECT name FROM system.tables WHERE database = '$DATABASE' AND engine NOT LIKE '%View' AND engine != 'MaterializedView' ORDER BY name"
    
    echo "Fetching all tables..." >&2
    local all_tables=$(kubectl exec -n default $DEV_POD -- clickhouse-client \
        --host="$CLICKHOUSE_HOSTNAME" \
        --port="$CLICKHOUSE_NATIVE_PORT" \
        --user="$CLICKHOUSE_USER" \
        --password="$CLICKHOUSE_PASSWORD" \
        --database="$DATABASE" \
        --secure \
        --connect_timeout=30 \
        --receive_timeout=300 \
        --send_timeout=300 \
        --query="$query" 2>/dev/null)
    
    if [ -z "$all_tables" ]; then
        echo -e "${RED}No tables found in database${NC}" >&2
        exit 1
    fi
    
    # Apply regex filter if specified
    local filtered_tables=""
    if [ -n "$TABLE_FILTER" ]; then
        echo "Applying regex filter: $TABLE_FILTER" >&2
        filtered_tables=$(echo "$all_tables" | grep -E "$TABLE_FILTER" || true)
        
        if [ -z "$filtered_tables" ]; then
            echo -e "${RED}No tables match the filter pattern '$TABLE_FILTER'${NC}" >&2
            echo -e "${YELLOW}Available tables:${NC}" >&2
            echo "$all_tables" | sed 's/^/  - /' >&2
            exit 1
        fi
        
        echo "$filtered_tables"
    else
        echo "$all_tables"
    fi
}

# Function to optimize a table
optimize_table() {
    local table_name="$1"
    
    echo -e "\n${YELLOW}Optimizing table: $table_name${NC}"
    
    local optimize_query="OPTIMIZE TABLE \`$table_name\` FINAL"
    execute_query "$optimize_query" "Running OPTIMIZE TABLE FINAL..."
}

# Main execution
main() {
    # Get credentials
    get_clickhouse_password
    
    # Find dev-pod
    find_dev_pod
    
    # Setup clickhouse-client
    setup_clickhouse_client
    
    # Get tables to optimize
    TABLES=$(get_tables_to_optimize)
    
    if [ -z "$TABLES" ]; then
        echo -e "${RED}No tables found${NC}"
        exit 1
    fi
    
    # Count tables
    TABLE_COUNT=$(echo "$TABLES" | wc -l)
    echo -e "\n${GREEN}Found $TABLE_COUNT table(s) to optimize${NC}"
    
    # If dry-run, list all tables that would be optimized
    if [ "$DRY_RUN" = true ]; then
        echo -e "\n${YELLOW}Tables that would be optimized:${NC}"
        echo "$TABLES" | while IFS= read -r table; do
            echo "  - $table"
        done
        echo ""
        exit 0
    fi
    
    echo -e "\n${GREEN}Optimizing tables...${NC}"
    echo -e "${YELLOW}WARNING: This operation can be resource intensive and may take time for large tables${NC}"
    
    # Optimize each table
    local success_count=0
    local failure_count=0
    
    while IFS= read -r table_name; do
        if [ -n "$table_name" ]; then
            if optimize_table "$table_name"; then
                success_count=$((success_count + 1))
            else
                failure_count=$((failure_count + 1))
                echo -e "${RED}✗ Failed to optimize table: $table_name${NC}"
            fi
        fi
    done <<< "$TABLES"
    
    echo -e "\n${GREEN}Optimization Summary:${NC}"
    echo "  Successfully optimized: $success_count tables"
    if [ $failure_count -gt 0 ]; then
        echo -e "  ${RED}Failed to optimize: $failure_count tables${NC}"
    fi
    
    if [ $failure_count -eq 0 ]; then
        echo -e "\n${GREEN}✓ All tables optimized successfully!${NC}"
    else
        echo -e "\n${YELLOW}⚠ Some tables failed to optimize. Check the output above for details.${NC}"
        exit 1
    fi
}

# Run main function
main