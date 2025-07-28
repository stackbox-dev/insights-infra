#!/bin/bash

# Zeppelin troubleshooting script for Flink Studio
# This script helps diagnose connectivity and configuration issues

set -e

NAMESPACE="flink-studio"

echo "🔍 Zeppelin Troubleshooting for Flink Studio"
echo "============================================="

# Function to check pod status
check_pod_status() {
    local label=$1
    local component=$2
    
    echo ""
    echo "📦 Checking $component pods..."
    kubectl get pods -l $label -n $NAMESPACE -o wide
    
    # Get pod names
    local pods=$(kubectl get pods -l $label -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')
    
    for pod in $pods; do
        echo ""
        echo "🔍 Pod $pod status:"
        kubectl describe pod $pod -n $NAMESPACE | grep -A 10 "Conditions:"
        
        echo ""
        echo "📋 Recent logs for $pod:"
        kubectl logs --tail=20 $pod -n $NAMESPACE || echo "❌ Could not fetch logs"
    done
}

# Function to test connectivity
test_connectivity() {
    local service=$1
    local port=$2
    local endpoint=${3:-"/"}
    
    echo ""
    echo "🔗 Testing connectivity to $service:$port$endpoint"
    
    # Create a test pod
    kubectl run connectivity-test --image=curlimages/curl --rm -i --restart=Never -n $NAMESPACE -- \
        curl -s --connect-timeout 10 http://$service:$port$endpoint && echo "✅ Connection successful" || echo "❌ Connection failed"
}

# Check namespace
echo "🏠 Checking namespace $NAMESPACE..."
if kubectl get namespace $NAMESPACE &> /dev/null; then
    echo "✅ Namespace $NAMESPACE exists"
else
    echo "❌ Namespace $NAMESPACE does not exist"
    exit 1
fi

# Check Flink components
echo ""
echo "🔍 Checking Flink components..."
echo "Flink Session Cluster:"
kubectl get flinkdeployment flink-session-cluster -n $NAMESPACE -o wide || echo "❌ Flink Session Cluster not found"

echo ""
echo "Flink SQL Gateway:"
kubectl get deployment flink-sql-gateway -n $NAMESPACE -o wide || echo "❌ Flink SQL Gateway not found"

# Check Zeppelin components
echo ""
echo "🔍 Checking Zeppelin components..."
echo "Zeppelin ConfigMap:"
kubectl get configmap zeppelin-config -n $NAMESPACE || echo "❌ Zeppelin ConfigMap not found"

echo ""
echo "Zeppelin StatefulSet:"
kubectl get statefulset zeppelin -n $NAMESPACE -o wide || echo "❌ Zeppelin StatefulSet not found"

echo ""
echo "Zeppelin Services:"
kubectl get services -l app.kubernetes.io/name=zeppelin -n $NAMESPACE || echo "❌ Zeppelin Services not found"

# Check pod status
check_pod_status "app.kubernetes.io/name=zeppelin" "Zeppelin"
check_pod_status "app.kubernetes.io/name=flink-sql-gateway" "Flink SQL Gateway"
check_pod_status "app=flink-session-cluster" "Flink Session Cluster"

# Test connectivity
test_connectivity "flink-sql-gateway" "80" "/v1/info"
test_connectivity "flink-session-cluster" "80" "/"
test_connectivity "zeppelin-service" "80" "/"

# Check Zeppelin configuration
echo ""
echo "📋 Checking Zeppelin interpreter configuration..."
kubectl get configmap zeppelin-config -n $NAMESPACE -o jsonpath='{.data.interpreter\.json}' | jq . 2>/dev/null || echo "❌ Could not parse interpreter.json"

# Check GCP service account
echo ""
echo "🔑 Checking GCP service account secret..."
kubectl get secret gcp-service-account-key -n $NAMESPACE || echo "❌ GCP service account secret not found"

# Port forward instructions
echo ""
echo "🚀 Manual testing instructions:"
echo "1. Port forward to Zeppelin:"
echo "   kubectl port-forward service/zeppelin-service 8080:80 -n $NAMESPACE"
echo ""
echo "2. Port forward to Flink SQL Gateway:"
echo "   kubectl port-forward service/flink-sql-gateway 8081:80 -n $NAMESPACE"
echo ""
echo "3. Port forward to Flink Session Cluster:"
echo "   kubectl port-forward service/flink-session-cluster 8082:80 -n $NAMESPACE"
echo ""
echo "4. Test URLs:"
echo "   - Zeppelin: http://localhost:8080"
echo "   - Flink SQL Gateway: http://localhost:8081/v1/info"
echo "   - Flink Session Cluster: http://localhost:8082"

echo ""
echo "📚 Common fixes:"
echo "1. Restart Zeppelin:"
echo "   kubectl rollout restart statefulset/zeppelin -n $NAMESPACE"
echo ""
echo "2. Check interpreter settings in Zeppelin UI:"
echo "   - Go to Interpreter menu"
echo "   - Check jdbc and flink interpreters"
echo "   - Verify connection URLs"
echo ""
echo "3. Recreate configuration:"
echo "   kubectl delete configmap zeppelin-config -n $NAMESPACE"
echo "   kubectl apply -f manifests/07-zeppelin-config.yaml"
