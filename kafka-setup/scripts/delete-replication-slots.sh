#!/bin/bash

# Script to delete all PostgreSQL replication slots with user confirmation
# Uses credentials from .env files in parent directory and Kubernetes secrets

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to load environment variables from .env file
load_env() {
    local env_file=$1
    if [[ -f "$env_file" ]]; then
        export $(cat "$env_file" | grep -v '^#' | xargs)
        return 0
    else
        echo -e "${RED}Error: Environment file $env_file not found${NC}"
        return 1
    fi
}

# Function to fetch password from Kubernetes secret
fetch_password_from_secret() {
    local secret_name=$1
    local namespace=${K8S_NAMESPACE:-default}
    
    # Try to get password from Kubernetes secret
    password=$(kubectl get secret "$secret_name" -n "$namespace" -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null)
    
    if [[ -z "$password" ]]; then
        # Try alternative field names
        password=$(kubectl get secret "$secret_name" -n "$namespace" -o jsonpath='{.data.postgresql-password}' 2>/dev/null | base64 -d 2>/dev/null)
    fi
    
    if [[ -z "$password" ]]; then
        echo -e "${RED}Warning: Could not fetch password from secret $secret_name${NC}" >&2
        return 1
    fi
    
    echo "$password"
    return 0
}

# Function to run psql command via dev-pod
run_psql() {
    local db_host=$1
    local db_port=$2
    local db_name=$3
    local db_user=$4
    local db_pass=$5
    local sql_command=$6
    local namespace=${K8S_NAMESPACE:-default}
    
    # Find dev-pod
    local dev_pod=$(kubectl get pods -n default -l app=dev-pod -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [[ -z "$dev_pod" ]]; then
        # Try without label
        dev_pod=$(kubectl get pods -n default | grep dev-pod | head -1 | awk '{print $1}')
    fi
    
    if [[ -z "$dev_pod" ]]; then
        echo -e "${RED}Error: Could not find dev-pod in default namespace${NC}" >&2
        return 1
    fi
    
    # Run psql command via kubectl exec
    kubectl exec -n default "$dev_pod" -- env PGPASSWORD="$db_pass" psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -c "$sql_command" 2>&1
}

# Function to run psql command and get output via dev-pod
run_psql_query() {
    local db_host=$1
    local db_port=$2
    local db_name=$3
    local db_user=$4
    local db_pass=$5
    local sql_command=$6
    local namespace=${K8S_NAMESPACE:-default}
    
    # Find dev-pod
    local dev_pod=$(kubectl get pods -n default -l app=dev-pod -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [[ -z "$dev_pod" ]]; then
        # Try without label
        dev_pod=$(kubectl get pods -n default | grep dev-pod | head -1 | awk '{print $1}')
    fi
    
    if [[ -z "$dev_pod" ]]; then
        echo -e "${RED}Error: Could not find dev-pod in default namespace${NC}" >&2
        return 1
    fi
    
    # Run psql command via kubectl exec with tuple-only output
    kubectl exec -n default "$dev_pod" -- env PGPASSWORD="$db_pass" psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -t -c "$sql_command" 2>/dev/null | sed 's/^[ \t]*//;s/[ \t]*$//'
}

# Function to delete replication slots for a database
delete_slots() {
    local db_host=$1
    local db_port=$2
    local db_name=$3
    local db_user=$4
    local db_pass=$5
    local db_label=$6
    
    echo -e "\n${YELLOW}=== $db_label Database ===${NC}"
    echo "Host: $db_host:$db_port"
    echo "Database: $db_name"
    
    # Get list of replication slots
    echo -e "\n${GREEN}Fetching replication slots...${NC}"
    # First, let's see all slots for debugging
    echo "Querying all replication slots in the cluster..."
    run_psql "$db_host" "$db_port" "$db_name" "$db_user" "$db_pass" "SELECT slot_name, database FROM pg_replication_slots;"
    
    # Query pg_replication_slots for this specific database
    slots=$(run_psql_query "$db_host" "$db_port" "$db_name" "$db_user" "$db_pass" "SELECT slot_name FROM pg_replication_slots WHERE database = '$db_name';")
    
    if [[ -z "$slots" ]]; then
        echo "No replication slots found in $db_label database."
        return 0
    fi
    
    echo -e "\n${YELLOW}Found replication slots:${NC}"
    echo "$slots"
    
    # Ask for confirmation
    echo -e "\n${RED}WARNING: This will delete ALL replication slots in $db_label database!${NC}"
    read -p "Do you want to proceed? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        echo "Skipping $db_label database."
        return 0
    fi
    
    # Delete each slot
    echo -e "\n${GREEN}Deleting replication slots...${NC}"
    while IFS= read -r slot; do
        if [[ -n "$slot" ]]; then
            echo -n "Deleting slot: $slot ... "
            if run_psql "$db_host" "$db_port" "$db_name" "$db_user" "$db_pass" "SELECT pg_drop_replication_slot('$slot');" >/dev/null 2>&1; then
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${RED}✗ (might be active or already deleted)${NC}"
            fi
        fi
    done <<< "$slots"
    
    echo -e "${GREEN}Completed processing $db_label database.${NC}"
}

# Parse command line arguments
ENV_FILE_ARG=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            ENV_FILE_ARG="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Usage: $0 [--env <env-file>]"
            exit 1
            ;;
    esac
done

# Main execution
echo -e "${YELLOW}=== PostgreSQL Replication Slot Deletion Tool ===${NC}"
echo "This script will delete replication slots from configured databases."

# Check for specific environment file argument
if [[ -n "$ENV_FILE_ARG" ]]; then
    ENV_FILE="$ENV_DIR/$ENV_FILE_ARG"
    if [[ ! -f "$ENV_FILE" ]]; then
        echo -e "${RED}Error: Specified environment file $ENV_FILE_ARG not found in $ENV_DIR${NC}"
        exit 1
    fi
    ENV_FILES=("$ENV_FILE")
    echo -e "${GREEN}Using environment file: $ENV_FILE_ARG${NC}"
else
    # Find all .env files
    ENV_FILES=()
    for file in "$ENV_DIR"/.*.env; do
        if [[ -f "$file" ]]; then
            ENV_FILES+=("$file")
        fi
    done
    
    if [[ ${#ENV_FILES[@]} -eq 0 ]]; then
        echo -e "${RED}Error: No .env files found in $ENV_DIR${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Found environment files:${NC}"
    for file in "${ENV_FILES[@]}"; do
        echo "  - $(basename "$file")"
    done
fi

# Process each environment
for env_file in "${ENV_FILES[@]}"; do
    echo -e "\n${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Processing: $(basename "$env_file")${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    # Load environment variables
    if ! load_env "$env_file"; then
        continue
    fi
    
    # Process each database if credentials are available
    
    # WMS Database
    if [[ -n "$WMS_DB_HOSTNAME" && -n "$WMS_DB_NAME" && -n "$WMS_DB_USER" && -n "$WMS_DB_PASSWORD_SECRET" ]]; then
        echo -e "\n${GREEN}Fetching WMS database password from Kubernetes secret...${NC}"
        WMS_PASSWORD=$(fetch_password_from_secret "$WMS_DB_PASSWORD_SECRET")
        if [[ -n "$WMS_PASSWORD" ]]; then
            delete_slots "$WMS_DB_HOSTNAME" "${WMS_DB_PORT:-5432}" "$WMS_DB_NAME" "$WMS_DB_USER" "$WMS_PASSWORD" "WMS"
        else
            echo -e "${RED}Failed to fetch WMS database password from secret${NC}"
        fi
    else
        echo -e "${YELLOW}WMS database configuration not found, skipping...${NC}"
    fi
    
    # Backbone Database
    if [[ -n "$BACKBONE_DB_HOSTNAME" && -n "$BACKBONE_DB_NAME" && -n "$BACKBONE_DB_USER" && -n "$BACKBONE_DB_PASSWORD_SECRET" ]]; then
        echo -e "\n${GREEN}Fetching BACKBONE database password from Kubernetes secret...${NC}"
        BACKBONE_PASSWORD=$(fetch_password_from_secret "$BACKBONE_DB_PASSWORD_SECRET")
        if [[ -n "$BACKBONE_PASSWORD" ]]; then
            delete_slots "$BACKBONE_DB_HOSTNAME" "${BACKBONE_DB_PORT:-5432}" "$BACKBONE_DB_NAME" "$BACKBONE_DB_USER" "$BACKBONE_PASSWORD" "BACKBONE"
        else
            echo -e "${RED}Failed to fetch BACKBONE database password from secret${NC}"
        fi
    else
        echo -e "${YELLOW}BACKBONE database configuration not found, skipping...${NC}"
    fi
    
    # Encarta Database
    if [[ -n "$ENCARTA_DB_HOSTNAME" && -n "$ENCARTA_DB_NAME" && -n "$ENCARTA_DB_USER" && -n "$ENCARTA_DB_PASSWORD_SECRET" ]]; then
        echo -e "\n${GREEN}Fetching ENCARTA database password from Kubernetes secret...${NC}"
        ENCARTA_PASSWORD=$(fetch_password_from_secret "$ENCARTA_DB_PASSWORD_SECRET")
        if [[ -n "$ENCARTA_PASSWORD" ]]; then
            delete_slots "$ENCARTA_DB_HOSTNAME" "${ENCARTA_DB_PORT:-5432}" "$ENCARTA_DB_NAME" "$ENCARTA_DB_USER" "$ENCARTA_PASSWORD" "ENCARTA"
        else
            echo -e "${RED}Failed to fetch ENCARTA database password from secret${NC}"
        fi
    else
        echo -e "${YELLOW}ENCARTA database configuration not found, skipping...${NC}"
    fi
done

echo -e "\n${GREEN}=== Script completed ===${NC}"