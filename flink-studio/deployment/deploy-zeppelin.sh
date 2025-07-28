#!/bin/bash

# Zeppelin deployment script for Flink Studio
# This script ensures proper deployment order and connectivity

set -e

NAMESPACE="flink-studio"
MANIFESTS_DIR="/Users/saby/Stackbox/insights-infra/flink-studio/deployment/manifests"

echo "🚀 Starting Zeppelin deployment for Flink Studio..."

# Function to wait for deployment to be ready
wait_for_deployment() {
    local deployment_name=$1
    local timeout=${2:-300}
    
    echo "⏳ Waiting for $deployment_name to be ready..."
    kubectl wait --for=condition=available --timeout=${timeout}s deployment/$deployment_name -n $NAMESPACE
    echo "✅ $deployment_name is ready"
}

# Function to wait for statefulset to be ready
wait_for_statefulset() {
    local statefulset_name=$1
    local timeout=${2:-300}
    
    echo "⏳ Waiting for $statefulset_name to be ready..."
    kubectl wait --for=condition=ready --timeout=${timeout}s pod -l app.kubernetes.io/name=$statefulset_name -n $NAMESPACE
    echo "✅ $statefulset_name is ready"
}

# Check if namespace exists
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    echo "❌ Namespace $NAMESPACE does not exist. Please create it first."
    exit 1
fi

# Check if Flink Session cluster is running
echo "🔍 Checking Flink Session cluster..."
if ! kubectl get flinkdeployment flink-session-cluster -n $NAMESPACE &> /dev/null; then
    echo "❌ Flink Session cluster not found. Please deploy it first."
    exit 1
fi

# Deploy Zeppelin configuration
echo "📋 Deploying Zeppelin configuration..."
kubectl apply -f "$MANIFESTS_DIR/07-zeppelin-config.yaml"

# Wait a moment for config to be propagated
sleep 5

# Deploy Zeppelin
echo "🎯 Deploying Zeppelin..."
kubectl apply -f "$MANIFESTS_DIR/08-zeppelin.yaml"

# Wait for Zeppelin to be ready
wait_for_statefulset "zeppelin" 300

# Check Zeppelin connectivity
echo "🔗 Testing Zeppelin connectivity..."
kubectl port-forward service/zeppelin-service 8080:80 -n $NAMESPACE &
PORT_FORWARD_PID=$!

# Wait for port forward to establish
sleep 10

# Test local connection
if curl -s http://localhost:8080 > /dev/null; then
    echo "✅ Zeppelin is accessible on http://localhost:8080"
else
    echo "⚠️  Zeppelin may not be fully ready yet. Check logs with:"
    echo "   kubectl logs -l app.kubernetes.io/name=zeppelin -n $NAMESPACE"
fi

# Kill port forward
kill $PORT_FORWARD_PID 2>/dev/null || true

echo ""
echo "🎉 Zeppelin deployment completed!"
echo ""
echo "📚 Access Zeppelin:"
echo "   kubectl port-forward service/zeppelin-service 8080:80 -n $NAMESPACE"
echo "   Then open: http://localhost:8080"
echo ""
echo "🔧 Configured Interpreters:"
echo "   - Flink Stream SQL: %flink.ssql (connects to flink-session-cluster:80)"
echo "   - Flink Batch SQL: %flink.bsql (connects to flink-session-cluster:80)"
echo ""
echo "📖 Test notebook guide: flink-studio/notebooks/flink-sql-test-guide.md"
echo ""
echo "🐛 Troubleshoot:"
echo "   kubectl logs -l app.kubernetes.io/name=zeppelin -n $NAMESPACE"
echo "   kubectl describe statefulset zeppelin -n $NAMESPACE"
