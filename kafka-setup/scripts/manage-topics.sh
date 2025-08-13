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

Manage Kafka topics - create, list, update, delete

REQUIRED:
    --env <file>       Environment configuration file (e.g., .sbx-uat.env)

COMMANDS:
    list               List topics with optional filtering
    create             Create a new topic
    update             Update topic configurations
    delete             Delete topics

LIST OPTIONS:
    --filter PATTERN   Filter topics by regex pattern
    --details          Show topic details (partitions, replication, configs)

CREATE OPTIONS:
    --topic <name>     Topic name to create (required)
    --partitions <n>   Number of partitions (default: 1)
    --replication <n>  Replication factor (default: 3)
    --config <k=v>     Additional configs (can be repeated)

UPDATE OPTIONS:
    --filter PATTERN   Filter topics to update (required)
    --cleanup-policy   Set cleanup policy: compact, delete, or infinite
    --config <k=v>     Set specific config (can be repeated)

DELETE OPTIONS:
    --filter PATTERN   Filter topics to delete (required)
    --force            Skip confirmation prompts

COMMON OPTIONS:
    --dry-run          Show what would be done without executing
    -h, --help         Show this help message

EXAMPLES:
    # List all topics
    $0 --env .sbx-uat.env list

    # List topics with details
    $0 --env .sbx-uat.env list --details

    # List topics matching pattern
    $0 --env .sbx-uat.env list --filter "^sbx_uat.wms.*"

    # Create a test topic
    $0 --env .sbx-uat.env create --topic test-topic --partitions 3

    # Create topic with configs
    $0 --env .sbx-uat.env create --topic important-topic --config retention.ms=-1 --config compression.type=lz4

    # Update topic to infinite retention
    $0 --env .sbx-uat.env update --filter "^test-topic$" --cleanup-policy infinite

    # Update specific configs
    $0 --env .sbx-uat.env update --filter "^test-.*" --config compression.type=snappy

    # Delete topics matching pattern
    $0 --env .sbx-uat.env delete --filter "^test-.*"

    # Delete with dry-run
    $0 --env .sbx-uat.env delete --filter "^temp-.*" --dry-run

EOF
}

# Parse global arguments
ENV_FILE=""
COMMAND=""
DRY_RUN=false

# Parse initial arguments to get env and command
temp_args=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            ENV_FILE="$2"
            shift 2
            ;;
        list|create|update|delete)
            COMMAND="$1"
            shift
            break
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            temp_args+=("$1")
            shift
            ;;
    esac
done

# Validate required arguments
if [ -z "$ENV_FILE" ]; then
    print_error "Environment file is required (--env)"
    usage
    exit 1
fi

if [ -z "$COMMAND" ]; then
    print_error "Command is required (list, create, update, delete)"
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

# Function to list topics
list_topics() {
    local filter_pattern=""
    local show_details=false
    
    # Parse list-specific arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --filter)
                filter_pattern="$2"
                shift 2
                ;;
            --details)
                show_details=true
                shift
                ;;
            --dry-run)
                # Already handled globally
                shift
                ;;
            *)
                print_error "Unknown list option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    print_info "Fetching topics..."
    all_topics=$(execute_kafka_command "$CONNECT_POD" "kafka-topics --list")
    
    if [ -z "$all_topics" ]; then
        print_warning "No topics found"
        return
    fi
    
    # Apply filter if provided
    if [ -n "$filter_pattern" ]; then
        filtered_topics=$(echo "$all_topics" | grep -E "$filter_pattern" 2>/dev/null || true)
        if [ -z "$filtered_topics" ]; then
            print_warning "No topics match filter: $filter_pattern"
            return
        fi
        topic_list="$filtered_topics"
    else
        topic_list="$all_topics"
    fi
    
    # Sort topics
    topic_list=$(echo "$topic_list" | sort)
    topic_count=$(echo "$topic_list" | wc -l | xargs)
    
    print_color $BLUE "=================================="
    print_color $BLUE "    Kafka Topics ($topic_count)    "
    print_color $BLUE "=================================="
    
    if [ -n "$filter_pattern" ]; then
        print_color $YELLOW "Filter: $filter_pattern"
    fi
    echo ""
    
    if [ "$show_details" = true ]; then
        # Show detailed information for each topic
        for topic in $topic_list; do
            echo "📋 $topic"
            
            # Get topic details from REST API
            details=$(kubectl exec -n "$K8S_NAMESPACE" "$CONNECT_POD" -- bash -c "
                curl -s -X GET '${KAFKA_REST_URL}/topics/${topic}' \
                    -u '\${CLUSTER_USER_NAME}:\${CLUSTER_PASSWORD}' \
                    -H 'Accept: application/json'
            " 2>/dev/null | jq -r '.configs | "   Partitions: \(.partitions // "N/A"), Replication: \(.replication // "N/A"), Retention: \(.["retention.ms"] // "default"), Cleanup: \(.["cleanup.policy"] // "delete"), Compression: \(.["compression.type"] // "producer")"' 2>/dev/null || echo "   [Unable to fetch details]")
            
            echo "$details"
            echo ""
        done
    else
        # Simple list
        echo "$topic_list"
    fi
}

# Function to create topic
create_topic() {
    local topic_name=""
    local partitions=1
    local replication=3
    local config_args=""
    
    # Parse create-specific arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --topic)
                topic_name="$2"
                shift 2
                ;;
            --partitions)
                partitions="$2"
                shift 2
                ;;
            --replication)
                replication="$2"
                shift 2
                ;;
            --config)
                if [ -n "$config_args" ]; then
                    config_args="$config_args --config $2"
                else
                    config_args="--config $2"
                fi
                shift 2
                ;;
            --dry-run)
                # Already handled globally
                shift
                ;;
            *)
                print_error "Unknown create option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    if [ -z "$topic_name" ]; then
        print_error "Topic name is required (--topic)"
        usage
        exit 1
    fi
    
    # Check if topic already exists
    existing_topics=$(execute_kafka_command "$CONNECT_POD" "kafka-topics --list")
    if echo "$existing_topics" | grep -q "^${topic_name}$"; then
        print_warning "Topic '${topic_name}' already exists"
        return
    fi
    
    print_color $BLUE "Creating topic: ${topic_name}"
    print_info "Partitions: ${partitions}, Replication: ${replication}"
    if [ -n "$config_args" ]; then
        print_info "Additional configs: ${config_args}"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        print_color $YELLOW "[DRY RUN] Would create topic with:"
        echo "  kafka-topics --create --topic ${topic_name} --partitions ${partitions} --replication-factor ${replication} ${config_args}"
        return
    fi
    
    create_cmd="kafka-topics --create --topic ${topic_name} --partitions ${partitions} --replication-factor ${replication} ${config_args}"
    
    if execute_kafka_command "$CONNECT_POD" "$create_cmd"; then
        print_success "✅ Topic '${topic_name}' created successfully!"
    else
        print_error "Failed to create topic"
        exit 1
    fi
}

# Function to update topics
update_topics() {
    local filter_pattern=""
    local cleanup_policy=""
    local config_args=""
    
    # Parse update-specific arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --filter)
                filter_pattern="$2"
                shift 2
                ;;
            --cleanup-policy)
                cleanup_policy="$2"
                shift 2
                ;;
            --config)
                if [ -n "$config_args" ]; then
                    config_args="$config_args,$2"
                else
                    config_args="$2"
                fi
                shift 2
                ;;
            --dry-run)
                # Already handled globally
                shift
                ;;
            *)
                print_error "Unknown update option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    if [ -z "$filter_pattern" ]; then
        print_error "Filter pattern is required (--filter)"
        usage
        exit 1
    fi
    
    # Build config arguments
    if [ -n "$cleanup_policy" ]; then
        case $cleanup_policy in
            compact)
                config_args="cleanup.policy=compact${config_args:+,$config_args}"
                ;;
            delete)
                config_args="cleanup.policy=delete${config_args:+,$config_args}"
                ;;
            infinite)
                config_args="cleanup.policy=delete,retention.ms=-1${config_args:+,$config_args}"
                ;;
            *)
                print_error "Invalid cleanup policy: $cleanup_policy (use compact, delete, or infinite)"
                exit 1
                ;;
        esac
    fi
    
    if [ -z "$config_args" ]; then
        print_error "No configurations to update. Use --cleanup-policy or --config"
        exit 1
    fi
    
    # Get topics to update
    all_topics=$(execute_kafka_command "$CONNECT_POD" "kafka-topics --list")
    topics_to_update=$(echo "$all_topics" | grep -E "$filter_pattern" 2>/dev/null || true)
    
    if [ -z "$topics_to_update" ]; then
        print_warning "No topics match filter: $filter_pattern"
        return
    fi
    
    topic_count=$(echo "$topics_to_update" | wc -l | xargs)
    
    print_info "Topics to update ($topic_count):"
    echo "$topics_to_update" | head -10
    if [ $topic_count -gt 10 ]; then
        echo "... and $((topic_count - 10)) more"
    fi
    
    print_info "Configuration changes: $config_args"
    
    if [ "$DRY_RUN" = true ]; then
        print_color $YELLOW "[DRY RUN] Would update $topic_count topics"
        return
    fi
    
    read -p "Proceed with update? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_warning "Update cancelled"
        return
    fi
    
    success_count=0
    fail_count=0
    
    for topic in $topics_to_update; do
        echo -n "Updating $topic ... "
        
        update_cmd="kafka-configs --alter --entity-type topics --entity-name ${topic} --add-config ${config_args}"
        
        if execute_kafka_command "$CONNECT_POD" "$update_cmd" > /dev/null 2>&1; then
            print_success "✅"
            ((success_count++))
        else
            print_error "❌"
            ((fail_count++))
        fi
    done
    
    print_success "Update completed! Success: $success_count, Failed: $fail_count"
}

# Function to delete topics
delete_topics() {
    local filter_pattern=""
    local force=false
    
    # Parse delete-specific arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --filter)
                filter_pattern="$2"
                shift 2
                ;;
            --force)
                force=true
                shift
                ;;
            --dry-run)
                # Already handled globally
                shift
                ;;
            *)
                print_error "Unknown delete option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    if [ -z "$filter_pattern" ]; then
        print_error "Filter pattern is required (--filter)"
        usage
        exit 1
    fi
    
    # Get topics to delete
    all_topics=$(execute_kafka_command "$CONNECT_POD" "kafka-topics --list")
    
    # Apply filter and protections
    topics_to_delete=$(echo "$all_topics" | grep -E "$filter_pattern" 2>/dev/null || true)
    
    # Always protect signal topics
    topics_to_delete=$(echo "$topics_to_delete" | grep -v '^debezium-signals-' || true)
    
    # Filter out internal Kafka topics
    topics_to_delete=$(echo "$topics_to_delete" | grep -v '^__' || true)
    
    # Filter out Kafka Connect topics
    topics_to_delete=$(echo "$topics_to_delete" | grep -v '^connect-' || true)
    
    if [ -z "$topics_to_delete" ]; then
        print_warning "No topics match filter (after applying protections): $filter_pattern"
        return
    fi
    
    topic_count=$(echo "$topics_to_delete" | wc -l | xargs)
    
    if [ "$DRY_RUN" = true ]; then
        print_color $YELLOW "[DRY RUN MODE] Topics that would be deleted ($topic_count):"
    else
        print_color $RED "⚠️  Topics to delete ($topic_count):"
    fi
    echo "$topics_to_delete"
    echo ""
    print_color $YELLOW "Protected topics (excluded):"
    echo "  - Internal Kafka topics (__*)"
    echo "  - Kafka Connect topics (connect-*)"
    echo "  - Signal topics (debezium-signals-*)"
    
    if [ "$DRY_RUN" = true ]; then
        print_color $YELLOW "[DRY RUN] Would delete $topic_count topics"
        return
    fi
    
    if [ "$force" = false ]; then
        echo ""
        read -p "Are you sure you want to delete these topics? Type 'yes' to confirm: " confirm
        if [ "$confirm" != "yes" ]; then
            print_warning "Deletion cancelled"
            return
        fi
        
        read -p "Type the number of topics ($topic_count) to double-confirm: " confirm_count
        if [ "$confirm_count" != "$topic_count" ]; then
            print_warning "Deletion cancelled - count mismatch"
            return
        fi
    fi
    
    print_info "Deleting topics..."
    
    for topic in $topics_to_delete; do
        echo -n "Deleting $topic ... "
        
        if execute_kafka_command "$CONNECT_POD" "kafka-topics --delete --topic $topic" > /dev/null 2>&1; then
            print_success "✅"
        else
            print_error "❌"
        fi
    done
    
    print_success "Deletion completed!"
}

# Execute the appropriate command
case $COMMAND in
    list)
        list_topics "$@"
        ;;
    create)
        create_topic "$@"
        ;;
    update)
        update_topics "$@"
        ;;
    delete)
        delete_topics "$@"
        ;;
    *)
        print_error "Unknown command: $COMMAND"
        usage
        exit 1
        ;;
esac