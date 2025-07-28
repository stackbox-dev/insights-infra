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

# Check for help flag early to avoid environment setup if just showing help
for arg in "$@"; do
    if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
        # Setup environment first, then show help from Python script
        setup_venv
        python3 "$SCRIPT_DIR/flink_sql_executor.py" --help
        exit 0
    fi
done

# Setup Python environment
log_info "Setting up Python environment..."
setup_venv

# Execute the Python script with all original arguments
log_info "Executing Flink SQL Executor..."
if python3 "$SCRIPT_DIR/flink_sql_executor.py" "$@"; then
    log_success "SQL execution completed successfully!"
    exit 0
else
    exit_code=$?
    log_error "SQL execution failed!"
    exit $exit_code
fi
