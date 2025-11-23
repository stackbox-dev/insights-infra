#!/bin/bash

# ClickHouse table setup script using dev-pod
# This script connects to ClickHouse via dev-pod and executes SQL scripts

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
FORCE_XX=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --pattern)
            FILTER_PATTERN="$2"
            shift 2
            ;;
        --file)
            SPECIFIC_FILE="$2"
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
        --force)
            FORCE_XX=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --pattern <glob>      Filter SQL files by glob pattern (excludes XX- files)"
            echo "  --file <path>         Execute a specific file (allows XX- files with --force)"
            echo "  --env <file>          Environment file (default: .sbx-uat.env)"
            echo "  --database <name>     Override database from env file"
            echo "  --force               Allow execution of XX- prefixed files (requires --file)"
            echo "  --dry-run            Show what would be executed without running"
            echo "  --help               Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --pattern 'encarta/*.sql'                # Run encarta SQL files (excludes XX-)"
            echo "  $0 --pattern 'wms-pick-drop/*.sql'          # Run pick-drop SQL files (excludes XX-)"
            echo "  $0 --pattern '**/01-*.sql'                  # Run all first-order files"
            echo "  $0 --file wms-inventory/XX-backfill-hourly-position.sql --force  # Run specific backfill"
            echo "  $0 --env .prod.env                          # Use production environment"
            echo "  $0 --dry-run                                # Show all files that would run"
            echo "  $0                                           # Run all SQL files (excludes XX-)"
            echo ""
            echo "IMPORTANT:"
            echo "  - Files are executed in alphabetical order (use numbering like 01-, 02-, etc.)"
            echo "  - Files prefixed with XX- are excluded unless --file and --force are used"
            echo "  - XX- files must be run individually with explicit --file and --force flags"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate arguments
if [ -n "$SPECIFIC_FILE" ] && [ -n "$FILTER_PATTERN" ]; then
    echo -e "${RED}Error: Cannot use both --file and --pattern together${NC}"
    exit 1
fi

if [ "$FORCE_XX" = true ] && [ -z "$SPECIFIC_FILE" ]; then
    echo -e "${RED}Error: --force requires --file to specify which XX- file to run${NC}"
    exit 1
fi

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

# Support both CLICKHOUSE_NATIVE_PORT and CLICKHOUSE_PORT
CLICKHOUSE_NATIVE_PORT="${CLICKHOUSE_NATIVE_PORT:-${CLICKHOUSE_PORT}}"

# Validate required environment variables
if [ -z "$CLICKHOUSE_HOSTNAME" ] || [ -z "$CLICKHOUSE_NATIVE_PORT" ] || [ -z "$CLICKHOUSE_USER" ]; then
    echo -e "${RED}Error: Missing required ClickHouse configuration in $ENV_FILE${NC}"
    echo "Required variables: CLICKHOUSE_HOSTNAME, CLICKHOUSE_NATIVE_PORT (or CLICKHOUSE_PORT), CLICKHOUSE_USER"
    exit 1
fi

echo -e "${GREEN}ClickHouse Table Setup Script${NC}"
echo "================================"
echo "Environment: $ENV_FILE"
echo "Host: $CLICKHOUSE_HOSTNAME:$CLICKHOUSE_NATIVE_PORT"
echo "Database: $DATABASE"
echo "User: $CLICKHOUSE_USER"
if [ -n "$SPECIFIC_FILE" ]; then
    echo "File: $SPECIFIC_FILE"
    echo "Force XX files: $FORCE_XX"
elif [ -n "$FILTER_PATTERN" ]; then
    echo "Filter Pattern: $FILTER_PATTERN"
else
    echo "Mode: All files (excluding XX-)"
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

# Function to copy all SQL files to pod
copy_all_files_to_pod() {
    local -a sql_files=("$@")
    local tmp_dir="/tmp/clickhouse-sql-$$"

    echo "Copying all SQL files to pod..."

    # Create temporary directory in pod
    kubectl exec -n default $DEV_POD -- mkdir -p "$tmp_dir"

    # Copy all files at once
    for sql_file in "${sql_files[@]}"; do
        local file_name=$(basename "$sql_file")
        kubectl cp "$sql_file" "default/$DEV_POD:$tmp_dir/$file_name" 2>/dev/null
    done

    echo "$tmp_dir"
}

# Function to execute SQL file using persistent connection
execute_sql_file_in_session() {
    local sql_file=$1
    local tmp_dir=$2
    local file_name=$(basename "$sql_file")
    local dir_name=$(dirname "$sql_file" | xargs basename)

    echo -e "\n${YELLOW}Processing: $dir_name/$file_name${NC}"

    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY RUN] Would execute: $sql_file"
        return
    fi

    # Send the file path as a query to the persistent session
    # Use SOURCE command which is more efficient
    echo "SOURCE $tmp_dir/$file_name;"
}

# Function to cleanup temporary directory in pod
cleanup_pod_files() {
    local tmp_dir=$1
    if [ -n "$tmp_dir" ] && [ "$tmp_dir" != "/" ]; then
        kubectl exec -n default $DEV_POD -- rm -rf "$tmp_dir" 2>/dev/null || true
    fi
}

# Function to get SQL files based on pattern or mode
get_sql_files() {
    local all_files=""

    if [ -n "$SPECIFIC_FILE" ]; then
        # Specific file mode
        if [ -f "$BASE_DIR/$SPECIFIC_FILE" ]; then
            # Check if it's an XX- file and force is not set
            if [[ "$(basename "$SPECIFIC_FILE")" == XX-* ]] && [ "$FORCE_XX" != true ]; then
                echo -e "${RED}Error: File $SPECIFIC_FILE starts with XX- and requires --force flag${NC}" >&2
                return 1
            fi
            echo "$BASE_DIR/$SPECIFIC_FILE"
        else
            echo -e "${RED}Error: File $SPECIFIC_FILE not found${NC}" >&2
            return 1
        fi
    elif [ -n "$FILTER_PATTERN" ]; then
        # Pattern mode - use full glob support with globstar and brace expansion
        # Enable globstar and extended globbing if available (bash 4+)
        if [ -n "$BASH_VERSION" ]; then
            shopt -s globstar nullglob 2>/dev/null || true
            shopt -s extglob 2>/dev/null || true
        fi
        local -a files=()

        # Expand glob pattern relative to BASE_DIR
        cd "$BASE_DIR"

        # Use a subshell with eval to safely expand braces and globs
        # This allows patterns like {encarta,wms-*}/*.sql to work
        while IFS= read -r file; do
            if [ -f "$file" ]; then
                # Exclude XX- files unless force is enabled
                if [[ "$(basename "$file")" != XX-* ]]; then
                    files+=("$BASE_DIR/$file")
                fi
            fi
        done < <(bash -c "shopt -s globstar nullglob 2>/dev/null || true; for f in $FILTER_PATTERN; do [ -f \"\$f\" ] && echo \"\$f\"; done")

        cd - > /dev/null

        # Sort and output files using natural sort (numeric-aware)
        if [ ${#files[@]} -gt 0 ]; then
            printf '%s\n' "${files[@]}" | sort -V
        fi

        # Disable globstar and extglob
        if [ -n "$BASH_VERSION" ]; then
            shopt -u globstar nullglob extglob 2>/dev/null || true
        fi
    else
        # Default mode - all SQL files except XX-
        find "$BASE_DIR" -type f -name "*.sql" ! -name "XX-*" | sort -V
    fi
}

# Main execution
main() {
    # Get credentials
    get_clickhouse_password
    
    # Find dev-pod
    find_dev_pod
    
    # Setup clickhouse-client
    setup_clickhouse_client
    
    # Get SQL files
    SQL_FILES=$(get_sql_files)
    
    if [ -z "$SQL_FILES" ]; then
        echo -e "${RED}No SQL files found${NC}"
        if [ -n "$FILTER_PATTERN" ]; then
            echo "Check if pattern '$FILTER_PATTERN' matches any files"
        elif [ -n "$SPECIFIC_FILE" ]; then
            echo "Check if file '$SPECIFIC_FILE' exists"
        fi
        exit 1
    fi
    
    # Count files
    FILE_COUNT=$(echo "$SQL_FILES" | wc -l)
    echo -e "\n${GREEN}Found $FILE_COUNT SQL file(s) to process${NC}"
    
    # If dry-run, list all files that would be executed
    if [ "$DRY_RUN" = true ]; then
        echo -e "\n${YELLOW}Files that would be executed (in order):${NC}"
        echo "$SQL_FILES" | while IFS= read -r file; do
            echo "  - $(basename $(dirname "$file"))/$(basename "$file")"
        done
        echo ""
    fi
    
    # Check if any XX- files were excluded (only in non-specific mode)
    if [ -z "$SPECIFIC_FILE" ]; then
        local xx_count=0
        if [ -n "$FILTER_PATTERN" ]; then
            # Check for XX- files using glob pattern with brace expansion
            cd "$BASE_DIR"

            # Use a subshell to expand braces and globs
            xx_count=$(bash -c "shopt -s globstar nullglob 2>/dev/null || true; count=0; for f in $FILTER_PATTERN; do if [ -f \"\$f\" ] && [[ \"\$(basename \"\$f\")\" == XX-* ]]; then ((count++)); fi; done; echo \$count")

            cd - > /dev/null
        else
            # No pattern specified - check all directories
            xx_count=$(find "$BASE_DIR" -type f -name "XX-*.sql" | wc -l)
        fi

        if [ "$xx_count" -gt 0 ]; then
            echo -e "${YELLOW}Note: $xx_count XX- prefixed file(s) excluded. Use --file and --force to run them.${NC}"
        fi
    fi
    
    # Process files using a single persistent connection
    echo -e "\n${GREEN}Executing SQL files using persistent connection...${NC}"

    if [ "$DRY_RUN" = true ]; then
        # For dry-run, just show what would be executed
        while IFS= read -r sql_file; do
            if [ -n "$sql_file" ]; then
                local file_name=$(basename "$sql_file")
                local dir_name=$(dirname "$sql_file" | xargs basename)
                echo -e "\n${YELLOW}Processing: $dir_name/$file_name${NC}"
                echo "  [DRY RUN] Would execute: $sql_file"
            fi
        done <<< "$SQL_FILES"
    else
        # Convert SQL_FILES to array
        local -a sql_files_array=()
        while IFS= read -r sql_file; do
            if [ -n "$sql_file" ]; then
                sql_files_array+=("$sql_file")
            fi
        done <<< "$SQL_FILES"

        # Build a master SQL script by concatenating all files LOCALLY first
        local tmp_dir="/tmp/clickhouse-sql-$$"
        local master_script_pod="$tmp_dir/master.sql"
        local master_script_local="/tmp/clickhouse-master-$$.sql"

        echo "Building master execution script locally..."

        # Build master script locally by concatenating all SQL files
        > "$master_script_local"  # Create/truncate the file

        local file_count=0
        local total_files=${#sql_files_array[@]}

        for sql_file in "${sql_files_array[@]}"; do
            local file_name=$(basename "$sql_file")
            local dir_name=$(dirname "$sql_file" | xargs basename)
            ((file_count++))

            echo "  [$file_count/$total_files] Adding $dir_name/$file_name..."

            # Append to local master script
            echo "-- Processing: $dir_name/$file_name" >> "$master_script_local"
            cat "$sql_file" >> "$master_script_local"
            echo "" >> "$master_script_local"
        done

        echo "Copying master script to pod..."

        # Create temporary directory in pod
        kubectl exec -n default $DEV_POD -- mkdir -p "$tmp_dir"

        # Copy the master script to pod in one operation
        kubectl cp "$master_script_local" "default/$DEV_POD:$master_script_pod"

        # Clean up local temp file
        rm -f "$master_script_local"

        TMP_DIR="$tmp_dir"

        echo "Executing all SQL files in single connection..."

        # Execute the master script with a single connection
        local cmd_output=""
        local cmd_exit_code=0

        cmd_output=$(kubectl exec -n default $DEV_POD -- clickhouse-client \
            --host="$CLICKHOUSE_HOSTNAME" \
            --port="$CLICKHOUSE_NATIVE_PORT" \
            --user="$CLICKHOUSE_USER" \
            --password="$CLICKHOUSE_PASSWORD" \
            --database="$DATABASE" \
            --secure \
            --multiquery \
            --connect_timeout=30 \
            --receive_timeout=600 \
            --send_timeout=600 \
            --progress \
            --queries-file="$master_script_pod" 2>&1) || cmd_exit_code=$?

        # Display the output with appropriate coloring
        if [ -n "$cmd_output" ]; then
            echo "$cmd_output" | while IFS= read -r line; do
                if [[ $line == *"Processing:"* ]]; then
                    echo -e "\n${YELLOW}$line${NC}"
                elif [[ $line == *"Error"* ]] || [[ $line == *"Exception"* ]] || [[ $line == *"FAILED"* ]]; then
                    echo -e "  ${RED}$line${NC}"
                elif [[ $line == *"CREATE"* ]] || [[ $line == *"ALTER"* ]] || [[ $line == *"DROP"* ]] || [[ $line == *"Ok."* ]]; then
                    echo -e "  ${GREEN}$line${NC}"
                elif [[ $line == *"rows in set"* ]] || [[ $line == *"Elapsed:"* ]]; then
                    echo -e "  ${YELLOW}$line${NC}"
                else
                    echo "  $line"
                fi
            done
        fi

        # Cleanup
        cleanup_pod_files "$TMP_DIR"

        if [ $cmd_exit_code -eq 0 ]; then
            echo -e "\n${GREEN}✓ All SQL files processed successfully!${NC}"
        else
            echo -e "\n${RED}✗ Execution failed with exit code $cmd_exit_code${NC}"
            exit 1
        fi
    fi
}

# Run main function
main