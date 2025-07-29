#!/bin/bash
set -euo pipefail

# Flink Dependency Management System - Launcher
# This script sets up the Python environment and launches the Python dependency manager

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="${SCRIPT_DIR}/dependency_manager.py"
REQUIREMENTS_FILE="${SCRIPT_DIR}/requirements.txt"
VENV_DIR="${SCRIPT_DIR}/.venv"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Python 3 is available
check_python() {
    if command -v python3 >/dev/null 2>&1; then
        PYTHON_CMD="python3"
    elif command -v python >/dev/null 2>&1 && python --version | grep -q "Python 3"; then
        PYTHON_CMD="python"
    else
        log_error "Python 3 is required but not found. Please install Python 3."
        exit 1
    fi
    
    # Check Python version (minimum 3.7)
    PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | cut -d' ' -f2)
    MAJOR_VERSION=$(echo "$PYTHON_VERSION" | cut -d'.' -f1)
    MINOR_VERSION=$(echo "$PYTHON_VERSION" | cut -d'.' -f2)
    
    if [ "$MAJOR_VERSION" -lt 3 ] || ([ "$MAJOR_VERSION" -eq 3 ] && [ "$MINOR_VERSION" -lt 7 ]); then
        log_error "Python 3.7 or higher is required. Found: $PYTHON_VERSION"
        exit 1
    fi
    
    log_info "Using Python $PYTHON_VERSION at $(which $PYTHON_CMD)"
}

# Create virtual environment if it doesn't exist
setup_venv() {
    if [ ! -d "$VENV_DIR" ]; then
        log_info "Creating Python virtual environment..."
        $PYTHON_CMD -m venv "$VENV_DIR"
        log_success "Virtual environment created at $VENV_DIR"
    else
        log_info "Using existing virtual environment at $VENV_DIR"
    fi
}

# Activate virtual environment
activate_venv() {
    if [ -f "$VENV_DIR/bin/activate" ]; then
        source "$VENV_DIR/bin/activate"
        log_info "Virtual environment activated"
    else
        log_error "Virtual environment activation script not found"
        exit 1
    fi
}

# Install/upgrade dependencies
install_dependencies() {
    log_info "Installing/upgrading Python dependencies..."
    
    # Upgrade pip first
    pip install --upgrade pip
    
    # Install required packages
    if [ -f "$REQUIREMENTS_FILE" ]; then
        pip install -r "$REQUIREMENTS_FILE"
    else
        # Install basic requirements if file doesn't exist
        pip install requests packaging
    fi
    
    log_success "Dependencies installed"
}

# Create requirements.txt if it doesn't exist
create_requirements() {
    if [ ! -f "$REQUIREMENTS_FILE" ]; then
        log_info "Creating requirements.txt..."
        cat > "$REQUIREMENTS_FILE" << 'EOF'
# Flink Dependency Management System Requirements
requests>=2.28.0
packaging>=21.0
EOF
        log_success "Requirements file created at $REQUIREMENTS_FILE"
    fi
}

# Check if dependency_manager.py exists
check_python_script() {
    if [ ! -f "$PYTHON_SCRIPT" ]; then
        log_error "Python script not found: $PYTHON_SCRIPT"
        log_error "Please ensure dependency_manager.py is in the same directory as this script"
        exit 1
    fi
}

# Main setup function
setup_environment() {
    log_info "Setting up Flink Dependency Management System..."
    
    check_python
    check_python_script
    create_requirements
    setup_venv
    activate_venv
    install_dependencies
    
    log_success "Environment setup complete"
}

# Main execution
main() {
    # Handle setup command only
    if [ "${1:-}" = "setup" ]; then
        setup_environment
        exit 0
    fi
    
    # For all other commands, ensure environment is set up
    if [ ! -d "$VENV_DIR" ] || [ ! -f "$VENV_DIR/bin/activate" ]; then
        log_warning "Python environment not set up. Running setup first..."
        setup_environment
        echo
    else
        # Just activate existing environment
        activate_venv
        
        # Check if dependencies need updating
        if ! python -c "import requests, packaging" >/dev/null 2>&1; then
            log_warning "Dependencies missing or outdated. Installing..."
            install_dependencies
        fi
    fi
    
    # Launch Python script with all arguments
    log_info "Launching dependency manager..."
    python "$PYTHON_SCRIPT" "$@"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
