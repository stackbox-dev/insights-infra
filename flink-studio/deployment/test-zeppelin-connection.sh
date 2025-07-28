#!/bin/bash

# Zeppelin to Flink SQL Gateway Connection Test Script
# This script helps diagnose Zeppelin to Flink SQL Gateway connectivity issues

set -e

NAMESPACE="flink-studio"
echo "🔍 Testing Zeppelin to Flink SQL Gateway connectivity..."

echo ""
echo "1. Checking if SQL Gateway service is running..."
kubectl get svc flink-sql-gateway -n $NAMESPACE

echo ""
echo "2. Checking SQL Gateway pod status..."
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=flink-sql-gateway

echo ""
echo "3. Testing SQL Gateway endpoint from within cluster..."
kubectl run test-connection --rm -i --tty --image=curlimages/curl:latest --restart=Never -- \
  curl -s http://flink-sql-gateway.flink-studio.svc.cluster.local:80/v1/info || true

echo ""
echo "4. Checking Zeppelin pod status..."
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=zeppelin

echo ""
echo "5. Testing connectivity from Zeppelin pod..."
ZEPPELIN_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=zeppelin -o jsonpath='{.items[0].metadata.name}')
if [ -n "$ZEPPELIN_POD" ]; then
    echo "Using Zeppelin pod: $ZEPPELIN_POD"
    kubectl exec $ZEPPELIN_POD -n $NAMESPACE -- curl -s http://flink-sql-gateway:80/v1/info || echo "Connection failed from Zeppelin pod"
else
    echo "No Zeppelin pod found"
fi

echo ""
echo "6. Checking Zeppelin configuration..."
kubectl get configmap zeppelin-config -n $NAMESPACE -o yaml | grep -A 10 -B 5 "flink-sql-gateway"

echo ""
echo "7. Checking recent Zeppelin logs for connection errors..."
if [ -n "$ZEPPELIN_POD" ]; then
    kubectl logs $ZEPPELIN_POD -n $NAMESPACE --tail=30 | grep -i "flink\|error\|connection\|interpreter" || echo "No relevant logs found"
fi

echo ""
echo "8. SQL Gateway logs (last 20 lines)..."
kubectl logs deployment/flink-sql-gateway -n $NAMESPACE --tail=20

echo ""
echo "9. Checking Zeppelin service endpoints..."
kubectl get endpoints -n $NAMESPACE | grep zeppelin

echo ""
echo "✅ Connection test completed!"
echo ""
echo "Access Zeppelin at:"
echo "- Internal: http://zeppelin-service.flink-studio.svc.cluster.local"
echo "- Port-forward: kubectl port-forward svc/zeppelin-service 8080:80 -n flink-studio"
echo ""
echo "If issues persist:"
echo "- Check network policies: kubectl get networkpolicy -n $NAMESPACE"
echo "- Verify Flink cluster is running: kubectl get pods -n $NAMESPACE"
echo "- Check Zeppelin interpreter configuration in the UI"
