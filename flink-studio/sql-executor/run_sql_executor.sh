#!/bin/bash

# Flink SQL Executor Runner Script
# This script sets up the Python environment and runs the SQL executor

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to setup Python virtual environment
setup_venv() {
    if [ ! -d "$VENV_DIR" ]; then
        log_info "Creating Python virtual environment..."
        python3 -m venv "$VENV_DIR"
        log_success "Virtual environment created at $VENV_DIR"
    fi
    
    log_info "Activating virtual environment..."
    source "$VENV_DIR/bin/activate"
    
    log_info "Installing/updating dependencies..."
    pip install -q --upgrade pip
    pip install -q -r "$SCRIPT_DIR/requirements.txt"
    log_success "Dependencies installed"
}

# Function to check if Flink SQL Gateway is accessible
check_sql_gateway() {
    local url="${1:-http://localhost:8083}"
    
    log_info "Checking Flink SQL Gateway connectivity at $url..."
    
    if curl -s --connect-timeout 5 "$url/v1/info" > /dev/null 2>&1; then
        log_success "Flink SQL Gateway is accessible"
        return 0
    else
        log_warning "Flink SQL Gateway is not accessible at $url"
        log_warning "Make sure the Flink cluster is running and the SQL Gateway is enabled"
        return 1
    fi
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

This script runs the Flink SQL Executor with proper Python environment setup.

Options:
    -f, --file FILE           SQL file to execute
    -s, --sql QUERY          Inline SQL query to execute
    -u, --url URL            SQL Gateway URL (default: http://localhost:8083)
    -d, --dry-run            Show what would be executed without running
    -v, --verbose            Enable verbose logging (DEBUG level)
    -l, --log-file FILE      Log to file
    -h, --help               Show this help message

Examples:
    $0 --file /path/to/my_query.sql
    $0 --sql "SELECT * FROM my_table LIMIT 10"
    $0 --file my_query.sql --dry-run
    $0 --file my_query.sql --url http://flink-sql-gateway.default:8083
    $0 --file my_query.sql --verbose --log-file execution.log

EOF
}

# Parse command line arguments
SQL_FILE=""
SQL_QUERY=""
SQL_GATEWAY_URL="http://localhost:8083"
DRY_RUN=""
LOG_LEVEL="INFO"
LOG_FILE=""
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            SQL_FILE="$2"
            shift 2
            ;;
        -s|--sql)
            SQL_QUERY="$2"
            shift 2
            ;;
        -u|--url)
            SQL_GATEWAY_URL="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN="--dry-run"
            shift
            ;;
        -v|--verbose)
            LOG_LEVEL="DEBUG"
            shift
            ;;
        -l|--log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done

# Validate required arguments
if [ -z "$SQL_QUERY" ] && [ -z "$SQL_FILE" ]; then
    log_error "Either --sql or --file must be specified."
    show_usage
    exit 1
fi

# Ensure only one execution mode is specified
if [ -n "$SQL_QUERY" ] && [ -n "$SQL_FILE" ]; then
    log_error "Only one of --sql or --file can be specified at a time."
    show_usage
    exit 1
fi

# Check if SQL file exists (only if file is specified)
if [ -n "$SQL_FILE" ]; then
    if [ ! -f "$SQL_FILE" ]; then
        log_error "SQL file not found: $SQL_FILE"
        exit 1
    fi
    
    # Convert to absolute path if not already
    if [[ "$SQL_FILE" != /* ]]; then
        SQL_FILE="$(cd "$(dirname "$SQL_FILE")" && pwd)/$(basename "$SQL_FILE")"
    fi
fi

if [ -n "$SQL_QUERY" ]; then
    log_info "Starting Flink SQL Executor for inline query"
    log_info "SQL: $SQL_QUERY"
elif [ -n "$SQL_FILE" ]; then
    log_info "Starting Flink SQL Executor for SQL file: $SQL_FILE"
fi
log_info "SQL Gateway URL: $SQL_GATEWAY_URL"

# Setup Python environment
setup_venv

# Check SQL Gateway connectivity (optional - don't fail if not accessible for dry runs)
if [ -z "$DRY_RUN" ]; then
    if ! check_sql_gateway "$SQL_GATEWAY_URL"; then
        log_error "Cannot proceed without accessible SQL Gateway"
        exit 1
    fi
else
    check_sql_gateway "$SQL_GATEWAY_URL" || true
fi

# Build Python command
PYTHON_CMD=(
    python3 "$SCRIPT_DIR/flink_sql_executor.py"
    --sql-gateway-url "$SQL_GATEWAY_URL"
    --log-level "$LOG_LEVEL"
)

if [ -n "$SQL_QUERY" ]; then
    PYTHON_CMD+=("--sql" "$SQL_QUERY")
else
    PYTHON_CMD+=("--file" "$SQL_FILE")
fi

if [ -n "$DRY_RUN" ]; then
    PYTHON_CMD+=("$DRY_RUN")
fi

if [ -n "$LOG_FILE" ]; then
    PYTHON_CMD+=("--log-file" "$LOG_FILE")
fi

# Add any extra arguments
PYTHON_CMD+=("${EXTRA_ARGS[@]}")

if [ -n "$SQL_QUERY" ]; then
    log_info "Executing inline SQL query..."
else
    log_info "Executing SQL file..."
fi
log_info "Command: ${PYTHON_CMD[*]}"

# Execute the Python script
if "${PYTHON_CMD[@]}"; then
    log_success "SQL execution completed successfully!"
    exit 0
else
    log_error "SQL execution failed!"
    exit 1
fi
