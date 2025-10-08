#!/bin/bash

# Script to run all ClickHouse sink connectors
# This sets up all WMS and Encarta connectors in one go

# Check if env file parameter is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <env-file>"
    echo "Example: $0 .sbx-uat.env"
    exit 1
fi

ENV_FILE="$1"

# Check if env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Environment file '$ENV_FILE' not found"
    exit 1
fi

echo "=========================================="
echo "Starting all ClickHouse Sink Connectors"
echo "Using environment: $ENV_FILE"
echo "=========================================="
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Array of scripts to run
declare -a SCRIPTS=(
    "encarta-clickhouse-sink.sh"
    "oms-clickhouse-sink.sh"
    "wms-commons-sink.sh"
    "wms-storage-sink.sh"
    "wms-inventory-sink.sh"
    "wms-pick-drop-sink.sh"
    "wms-workstation-sink.sh"
)

# Track success/failure
declare -a FAILED_SCRIPTS=()

# Run each script
for script in "${SCRIPTS[@]}"; do
    SCRIPT_PATH="$SCRIPT_DIR/$script"
    
    if [ ! -f "$SCRIPT_PATH" ]; then
        echo "❌ Script not found: $script"
        FAILED_SCRIPTS+=("$script (not found)")
        continue
    fi
    
    echo "=========================================="
    echo "Running: $script"
    echo "=========================================="
    
    # Make script executable if it isn't already
    chmod +x "$SCRIPT_PATH"
    
    # Run the script with the env file
    if bash "$SCRIPT_PATH" "$ENV_FILE"; then
        echo "✅ Successfully configured: $script"
    else
        echo "❌ Failed to configure: $script"
        FAILED_SCRIPTS+=("$script")
    fi
    
    echo ""
done

# Summary
echo "=========================================="
echo "Summary"
echo "=========================================="

if [ ${#FAILED_SCRIPTS[@]} -eq 0 ]; then
    echo "✅ All connectors configured successfully!"
else
    echo "⚠️  Some connectors failed to configure:"
    for failed in "${FAILED_SCRIPTS[@]}"; do
        echo "  - $failed"
    done
    exit 1
fi