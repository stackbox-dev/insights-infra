#!/bin/bash

# Flink Studio Deployment Test Script
# Tests the complete Flink deployment including libraries, connectivity, and health checks

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="flink-studio"
DEPLOYMENT_NAME="flink-session-cluster"
EXPECTED_LIBS=(
    "flink-sql-avro-2.0.0.jar"
    "flink-sql-connector-kafka-4.0.0-2.0.jar"
    "google-auth-library-oauth2-http-1.19.0.jar"
    "google-cloud-core-2.8.1.jar"
)

# Helper functions
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

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check cluster connection
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check namespace
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace '$NAMESPACE' does not exist"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

check_deployment_status() {
    log_info "Checking deployment status..."
    
    # Check if FlinkDeployment exists
    if ! kubectl get flinkdeployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" &> /dev/null; then
        log_error "FlinkDeployment '$DEPLOYMENT_NAME' not found in namespace '$NAMESPACE'"
        return 1
    fi
    
    # Get deployment status
    local status=$(kubectl get flinkdeployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.status.lifecycleState}')
    if [[ "$status" != "STABLE" ]]; then
        log_warning "FlinkDeployment status is '$status' (expected: STABLE)"
    else
        log_success "FlinkDeployment is STABLE"
    fi
    
    return 0
}

check_pods_status() {
    log_info "Checking pod status..."
    
    # Get all pods related to the deployment
    local pods=$(kubectl get pods -n "$NAMESPACE" -l app="$DEPLOYMENT_NAME" -o jsonpath='{.items[*].metadata.name}')
    
    if [[ -z "$pods" ]]; then
        log_error "No pods found for deployment '$DEPLOYMENT_NAME'"
        return 1
    fi
    
    local all_ready=true
    
    for pod in $pods; do
        local ready=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
        local phase=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
        
        if [[ "$ready" == "True" && "$phase" == "Running" ]]; then
            log_success "Pod '$pod' is ready and running"
        else
            log_error "Pod '$pod' is not ready (Ready: $ready, Phase: $phase)"
            all_ready=false
        fi
    done
    
    if [[ "$all_ready" == "true" ]]; then
        log_success "All pods are ready and running"
        return 0
    else
        return 1
    fi
}

check_init_containers() {
    log_info "Checking init container logs..."
    
    local pods=$(kubectl get pods -n "$NAMESPACE" -l app="$DEPLOYMENT_NAME" -o jsonpath='{.items[*].metadata.name}')
    
    for pod in $pods; do
        log_info "Checking init container logs for pod: $pod"
        
        # Check if init container completed successfully
        local init_status=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.initContainerStatuses[0].state.terminated.exitCode}' 2>/dev/null || echo "unknown")
        
        if [[ "$init_status" == "0" ]]; then
            log_success "Init container for pod '$pod' completed successfully"
        else
            log_warning "Init container for pod '$pod' may have issues (exit code: $init_status)"
        fi
        
        # Show last few lines of init container logs
        echo "Last 5 lines of init container logs for $pod:"
        kubectl logs "$pod" -n "$NAMESPACE" -c flink-plugin-setup --tail=5 2>/dev/null || log_warning "Could not retrieve init container logs for $pod"
        echo ""
    done
}

check_libraries() {
    log_info "Checking required libraries in all pods..."
    
    local pods=$(kubectl get pods -n "$NAMESPACE" -l app="$DEPLOYMENT_NAME" -o jsonpath='{.items[*].metadata.name}')
    local all_libs_present=true
    
    for pod in $pods; do
        log_info "Checking libraries in pod: $pod"
        
        # Check shared volume first
        echo "Shared volume (/opt/flink/lib-extra/) contents:"
        kubectl exec "$pod" -n "$NAMESPACE" -- ls -la /opt/flink/lib-extra/ 2>/dev/null || log_warning "Could not list shared volume for $pod"
        
        # Check main lib directory
        echo "Main lib directory (/opt/flink/lib/) contents for critical libraries:"
        for lib in "${EXPECTED_LIBS[@]}"; do
            if kubectl exec "$pod" -n "$NAMESPACE" -- test -f "/opt/flink/lib/$lib" 2>/dev/null; then
                log_success "Library '$lib' found in pod '$pod'"
            else
                log_error "Library '$lib' NOT found in pod '$pod'"
                all_libs_present=false
                
                # Try to copy from shared volume if missing
                log_info "Attempting to copy missing library from shared volume..."
                if kubectl exec "$pod" -n "$NAMESPACE" -- test -f "/opt/flink/lib-extra/$lib" 2>/dev/null; then
                    kubectl exec "$pod" -n "$NAMESPACE" -- cp "/opt/flink/lib-extra/$lib" "/opt/flink/lib/" 2>/dev/null && \
                    log_success "Successfully copied '$lib' from shared volume" || \
                    log_error "Failed to copy '$lib' from shared volume"
                fi
            fi
        done
        echo ""
    done
    
    if [[ "$all_libs_present" == "true" ]]; then
        log_success "All required libraries are present in all pods"
        return 0
    else
        log_warning "Some libraries are missing. Check the logs above."
        return 1
    fi
}

check_flink_ui() {
    log_info "Checking Flink UI accessibility..."
    
    # Get JobManager service - using the actual service name from manifest
    local service_name="flink-session-cluster"
    
    # Port forward in background
    log_info "Starting port forward to Flink UI (localhost:8081)..."
    kubectl port-forward -n "$NAMESPACE" "svc/$service_name" 8081:80 &
    local port_forward_pid=$!
    
    # Wait a moment for port forward to establish
    sleep 3
    
    # Test UI accessibility
    if curl -s http://localhost:8081/config > /dev/null; then
        log_success "Flink UI is accessible at http://localhost:8081"
        
        # Get Flink version info
        local flink_version=$(curl -s http://localhost:8081/config | jq -r '.["flink-version"]' 2>/dev/null || echo "unknown")
        log_info "Flink version: $flink_version"
        
        # Check available task slots
        local task_slots=$(curl -s http://localhost:8081/overview | jq -r '.slots-total' 2>/dev/null || echo "unknown")
        log_info "Total task slots: $task_slots"
        
        ui_accessible=true
    else
        log_error "Flink UI is not accessible"
        ui_accessible=false
    fi
    
    # Clean up port forward
    kill $port_forward_pid 2>/dev/null || true
    
    if [[ "$ui_accessible" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

check_taskmanagers() {
    log_info "Checking TaskManager connectivity..."
    
    # Port forward to access Flink API - using the actual service name
    local service_name="flink-session-cluster"
    
    kubectl port-forward -n "$NAMESPACE" "svc/$service_name" 8081:80 &
    local port_forward_pid=$!
    sleep 3
    
    # Check TaskManager status
    local taskmanagers=$(curl -s http://localhost:8081/taskmanagers 2>/dev/null)
    if [[ -n "$taskmanagers" ]]; then
        local tm_count=$(echo "$taskmanagers" | jq -r '.taskmanagers | length' 2>/dev/null || echo "0")
        log_info "Number of registered TaskManagers: $tm_count"
        
        if [[ "$tm_count" -gt "0" ]]; then
            log_success "TaskManagers are registered with JobManager"
            taskmanagers_ok=true
        else
            log_error "No TaskManagers registered with JobManager"
            taskmanagers_ok=false
        fi
    else
        log_error "Could not retrieve TaskManager information"
        taskmanagers_ok=false
    fi
    
    # Clean up port forward
    kill $port_forward_pid 2>/dev/null || true
    
    if [[ "$taskmanagers_ok" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

test_kafka_connectivity() {
    log_info "Testing Kafka connectivity (basic library check)..."
    
    # Get a pod to test with
    local pod=$(kubectl get pods -n "$NAMESPACE" -l app="$DEPLOYMENT_NAME" -o jsonpath='{.items[0].metadata.name}')
    
    if [[ -z "$pod" ]]; then
        log_error "No pods available for testing"
        return 1
    fi
    
    # Check if Kafka connector libraries are available
    if kubectl exec "$pod" -n "$NAMESPACE" -- find /opt/flink/lib -name "*kafka*" | grep -q kafka; then
        log_success "Kafka connector libraries are present"
        
        # Additional check: verify the exact Kafka connector jar
        if kubectl exec "$pod" -n "$NAMESPACE" -- test -f "/opt/flink/lib/flink-sql-connector-kafka-4.0.0-2.0.jar" 2>/dev/null; then
            log_success "Correct Kafka connector version found: flink-sql-connector-kafka-4.0.0-2.0.jar"
        else
            log_warning "Expected Kafka connector jar not found, but other Kafka libraries are present"
        fi
        return 0
    else
        log_error "Kafka connector libraries not found"
        return 1
    fi
}

test_avro_support() {
    log_info "Testing Avro support (basic library check)..."
    
    # Get a pod to test with
    local pod=$(kubectl get pods -n "$NAMESPACE" -l app="$DEPLOYMENT_NAME" -o jsonpath='{.items[0].metadata.name}')
    
    if [[ -z "$pod" ]]; then
        log_error "No pods available for testing"
        return 1
    fi
    
    # Check if Avro classes are available
    if kubectl exec "$pod" -n "$NAMESPACE" -- find /opt/flink/lib -name "*avro*" | grep -q avro; then
        log_success "Avro libraries are present"
        return 0
    else
        log_error "Avro libraries not found"
        return 1
    fi
}

generate_test_report() {
    log_info "Generating test report..."
    
    echo ""
    echo "=================================="
    echo "    FLINK DEPLOYMENT TEST REPORT"
    echo "=================================="
    echo "Timestamp: $(date)"
    echo "Namespace: $NAMESPACE"
    echo "Deployment: $DEPLOYMENT_NAME"
    echo ""
    
    # Summary of results
    local total_tests=7
    local passed_tests=0
    
    echo "TEST RESULTS:"
    echo "============="
    
    if check_deployment_status &>/dev/null; then
        echo "✅ Deployment Status: PASSED"
        ((passed_tests++))
    else
        echo "❌ Deployment Status: FAILED"
    fi
    
    if check_pods_status &>/dev/null; then
        echo "✅ Pod Status: PASSED"
        ((passed_tests++))
    else
        echo "❌ Pod Status: FAILED"
    fi
    
    if check_libraries &>/dev/null; then
        echo "✅ Library Check: PASSED"
        ((passed_tests++))
    else
        echo "❌ Library Check: FAILED"
    fi
    
    if check_flink_ui &>/dev/null; then
        echo "✅ Flink UI: PASSED"
        ((passed_tests++))
    else
        echo "❌ Flink UI: FAILED"
    fi
    
    if check_taskmanagers &>/dev/null; then
        echo "✅ TaskManager Connectivity: PASSED"
        ((passed_tests++))
    else
        echo "❌ TaskManager Connectivity: FAILED"
    fi
    
    if check_init_containers &>/dev/null; then
        echo "✅ Init Containers: PASSED"
        ((passed_tests++))
    else
        echo "❌ Init Containers: FAILED"
    fi
    
    if test_avro_support &>/dev/null; then
        echo "✅ Avro Support: PASSED"
        ((passed_tests++))
    else
        echo "❌ Avro Support: FAILED"
    fi
    
    echo ""
    echo "OVERALL RESULT: $passed_tests/$total_tests tests passed"
    
    if [[ $passed_tests -eq $total_tests ]]; then
        log_success "All tests passed! Deployment is healthy."
        return 0
    else
        log_warning "Some tests failed. Check the detailed output above."
        return 1
    fi
}

# Main execution
main() {
    echo "Starting Flink Studio Deployment Tests..."
    echo "=========================================="
    echo ""
    
    # Run all checks
    check_prerequisites
    echo ""
    
    check_deployment_status
    echo ""
    
    check_pods_status
    echo ""
    
    check_init_containers
    echo ""
    
    check_libraries
    echo ""
    
    check_flink_ui
    echo ""
    
    check_taskmanagers
    echo ""
    
    test_avro_support
    echo ""
    
    # Generate final report
    generate_test_report
}

# Parse command line arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Test the Flink Studio deployment including libraries, connectivity, and health checks."
        echo ""
        echo "Options:"
        echo "  --help, -h          Show this help message"
        echo "  --libs-only         Test only library presence"
        echo "  --connectivity-only Test only connectivity"
        echo "  --quick             Run quick tests only (skip detailed checks)"
        echo ""
        echo "Examples:"
        echo "  $0                  # Run all tests"
        echo "  $0 --libs-only      # Test only libraries"
        echo "  $0 --quick          # Run quick health check"
        exit 0
        ;;
    --libs-only)
        log_info "Running library checks only..."
        check_prerequisites
        check_libraries
        exit $?
        ;;
    --connectivity-only)
        log_info "Running connectivity checks only..."
        check_prerequisites
        check_flink_ui
        check_taskmanagers
        exit $?
        ;;
    --quick)
        log_info "Running quick health check..."
        check_prerequisites
        check_deployment_status
        check_pods_status
        exit $?
        ;;
    "")
        # Run main function
        main
        exit $?
        ;;
    *)
        log_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
