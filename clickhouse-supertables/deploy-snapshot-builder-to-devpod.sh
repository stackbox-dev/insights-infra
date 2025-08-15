#!/bin/bash

# Deploy snapshot builder scripts to dev pod
# Usage: ./deploy-snapshot-builder-to-devpod.sh <env-file>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}Error: Environment file required${NC}"
    echo "Usage: $0 <env-file>"
    echo ""
    echo "Available env files:"
    ls -1 *.env 2>/dev/null | sed 's/^/  - /' || echo "  No .env files found"
    echo ""
    echo "Examples:"
    echo "  $0 .sbx-uat.env"
    echo "  $0 .prod.env"
    exit 1
fi

ENV_FILE="$1"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

# Auto-detect dev pod (looking for pods with 'dev' in the name)
echo "Looking for dev pod..."
POD_NAME=$(kubectl get pods --no-headers | grep -i dev | head -1 | awk '{print $1}')

if [ -z "$POD_NAME" ]; then
    echo -e "${RED}Error: No dev pod found${NC}"
    echo "Available pods:"
    kubectl get pods --no-headers | awk '{print "  - " $1}'
    echo ""
    echo "Please ensure a dev pod is running (should contain 'dev' in the name)"
    exit 1
fi

echo -e "${GREEN}Found dev pod: $POD_NAME${NC}"

# Check if env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: Environment file '$ENV_FILE' not found${NC}"
    echo "Available env files:"
    ls -1 *.env 2>/dev/null | sed 's/^/  - /' || echo "  No .env files found"
    exit 1
fi

echo -e "${GREEN}=== Deploying to Dev Pod ===${NC}"
echo "Pod: $POD_NAME"
echo "Env file: $ENV_FILE"
echo ""

echo "Preparing deployment..."

# Get the working directory from the pod (usually /workspace or /home/user)
WORKDIR=$(kubectl exec "$POD_NAME" -- pwd)
echo "Pod working directory: $WORKDIR"

TARGET_DIR="$WORKDIR/inventory-snapshots"

# Create target directory in pod workdir
echo "Creating directory in pod..."
kubectl exec "$POD_NAME" -- mkdir -p "$TARGET_DIR"

# Copy the build script
echo "Copying build script..."
kubectl cp wms-inventory/build-inventory-snapshots.sh "$POD_NAME":"$TARGET_DIR"/build-inventory-snapshots.sh

# Copy the SQL file
echo "Copying SQL file..."
kubectl cp wms-inventory/XX-snapshot-build-configurable.sql "$POD_NAME":"$TARGET_DIR"/XX-snapshot-build-configurable.sql

# Fetch ClickHouse password from secret and create complete env file
echo "Preparing environment file with credentials..."
CLICKHOUSE_PASSWORD=$(kubectl get secret clickhouse-admin -n kafka -o jsonpath='{.data.password}' | base64 --decode)
if [ -z "$CLICKHOUSE_PASSWORD" ]; then
    echo -e "${RED}Error: Could not fetch ClickHouse password from secret${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Credentials fetched from Kubernetes secret${NC}"

# Create a temporary env file with the password included
TEMP_ENV=$(mktemp)
cp "$ENV_FILE" "$TEMP_ENV"
echo "" >> "$TEMP_ENV"
echo "# Password fetched from Kubernetes secret" >> "$TEMP_ENV"
echo "CLICKHOUSE_PASSWORD=$CLICKHOUSE_PASSWORD" >> "$TEMP_ENV"

# Copy the complete environment file
echo "Copying environment file..."
kubectl cp "$TEMP_ENV" "$POD_NAME":"$TARGET_DIR"/.env
rm "$TEMP_ENV"

# Create a simple README for the pod
TEMP_README=$(mktemp)
cat > "$TEMP_README" << 'EOF'
# Inventory Snapshot Builder

This package contains scripts to build inventory snapshots in ClickHouse.

## Files:
- `build-inventory-snapshots.sh` - Main build script
- `.env` - Environment configuration (ClickHouse credentials)
- `XX-snapshot-build-configurable.sql` - SQL script for snapshot creation

## Usage:

### Dry run (see what would be created):
```bash
./build-inventory-snapshots.sh --interval-days 1 --lookback-days 7 --env .env --dry-run
```

### Build daily snapshots for last 30 days:
```bash
./build-inventory-snapshots.sh --interval-days 1 --lookback-days 30 --env .env
```

### Build weekly snapshots from beginning:
```bash
./build-inventory-snapshots.sh --interval-days 7 --lookback-days 0 --env .env
```

### Build monthly snapshots:
```bash
./build-inventory-snapshots.sh --interval-days 30 --lookback-days 0 --env .env
```

## Parameters:
- `--interval-days`: Interval between snapshots (0.25=6hrs, 1=daily, 7=weekly, 30=monthly)
- `--lookback-days`: How far back to look (0=from beginning)
- `--env`: Environment file with ClickHouse credentials
- `--dry-run`: Show what would be created without executing
EOF

kubectl cp "$TEMP_README" "$POD_NAME":"$TARGET_DIR"/README.md
rm "$TEMP_README"

# Make script executable in pod
echo "Setting permissions..."
kubectl exec "$POD_NAME" -- chmod +x "$TARGET_DIR"/build-inventory-snapshots.sh

# Verify deployment
echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo "Files deployed to: $TARGET_DIR/"
echo ""
echo "To use the scripts, exec into the pod:"
echo -e "  ${YELLOW}kubectl exec -it $POD_NAME -- bash${NC}"
echo ""
echo "Then navigate to the directory:"
echo -e "  ${YELLOW}cd inventory-snapshots${NC}"
echo ""
echo "Run a dry-run first to see what will be created:"
echo -e "  ${YELLOW}./build-inventory-snapshots.sh --interval-days 1 --lookback-days 7 --env .env --dry-run${NC}"
echo ""
echo "View the README for more examples:"
echo -e "  ${YELLOW}cat README.md${NC}"

# Optional: Show what's in the directory
echo ""
echo "Contents of $TARGET_DIR/:"
kubectl exec "$POD_NAME" -- ls -la "$TARGET_DIR"