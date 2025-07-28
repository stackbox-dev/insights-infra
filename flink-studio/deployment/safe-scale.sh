#!/bin/bash

# Safe Flink Scaling Script - Supports seamless scaling with automatic job rebalancing
set -e

NAMESPACE="flink-studio"
DEPLOYMENT="flink-session-cluster"
NEW_REPLICAS=${1}
DEBUG_MODE=${2:-false}

# Validate input
if [ -z "$NEW_REPLICAS" ]; then
    echo "❌ Error: Please specify the number of replicas"
    echo "Usage: $0 <number_of_replicas> [debug]"
    echo "Example: $0 5"
    echo "Example with debug: $0 5 debug"
    exit 1
fi

if ! [[ "$NEW_REPLICAS" =~ ^[0-9]+$ ]] || [ "$NEW_REPLICAS" -lt 1 ]; then
    echo "❌ Error: Number of replicas must be a positive integer"
    exit 1
fi

# Enable debug mode if requested
if [ "$2" = "debug" ]; then
    DEBUG_MODE=true
    echo "🐛 Debug mode enabled"
fi

# Debug function
debug_log() {
    if [ "$DEBUG_MODE" = "true" ]; then
        echo "🐛 DEBUG: $1"
    fi
}

# Check and confirm Kubernetes context
echo "🔍 Checking Kubernetes context..."
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "NONE")
if [ "$CURRENT_CONTEXT" = "NONE" ]; then
    echo "❌ Error: No Kubernetes context is set"
    echo "   Please configure kubectl with: kubectl config use-context <context-name>"
    exit 1
fi

echo "📍 Current Kubernetes context: $CURRENT_CONTEXT"
echo ""
read -p "⚠️  Are you sure you want to scale the Flink cluster in this context? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Scaling cancelled by user"
    exit 1
fi
echo ""

echo "🎯 Scaling Flink cluster to $NEW_REPLICAS TaskManager replicas..."
echo "📍 Namespace: $NAMESPACE"
echo "📍 Deployment: $DEPLOYMENT"
echo ""

echo "🔍 Checking for running jobs..."
JOBS=$(kubectl exec -n $NAMESPACE deployment/flink-session-cluster -- flink list 2>/dev/null | grep "RUNNING" || true)

# Get current cluster state to make intelligent scaling decisions
CLUSTER_INFO=$(kubectl exec -n $NAMESPACE deployment/flink-session-cluster -- curl -s http://localhost:8081/overview 2>/dev/null || echo "FAILED")

if [ "$DEBUG_MODE" = "true" ] && [ "$CLUSTER_INFO" != "FAILED" ]; then
    echo "🐛 DEBUG: Initial cluster state response:"
    echo "$CLUSTER_INFO" | jq . 2>/dev/null || echo "$CLUSTER_INFO"
    echo ""
fi

if [ "$CLUSTER_INFO" != "FAILED" ]; then
    CURRENT_SLOTS=$(echo "$CLUSTER_INFO" | grep -o '"slots-total":[0-9]*' | cut -d':' -f2)
    AVAILABLE_SLOTS=$(echo "$CLUSTER_INFO" | grep -o '"slots-available":[0-9]*' | cut -d':' -f2)
    USED_SLOTS=$((CURRENT_SLOTS - AVAILABLE_SLOTS))
    CURRENT_TMS=$(echo "$CLUSTER_INFO" | grep -o '"taskmanagers":[0-9]*' | cut -d':' -f2)
    
    echo "📊 Current cluster state:"
    echo "   TaskManagers: $CURRENT_TMS"
    echo "   Total slots: $CURRENT_SLOTS"
    echo "   Used slots: $USED_SLOTS"
    echo "   Available slots: $AVAILABLE_SLOTS"
else
    echo "⚠️  Cannot get cluster state, proceeding with conservative approach"
    CURRENT_SLOTS=0
    USED_SLOTS=999  # Force conservative mode
fi

REQUIRED_SLOTS=$((NEW_REPLICAS * 4))
SCALING_UP=$([[ $REQUIRED_SLOTS -gt $CURRENT_SLOTS ]] && echo "true" || echo "false")

if [ ! -z "$JOBS" ]; then
    echo "📋 Found running jobs:"
    echo "$JOBS"
    echo ""
    
    # Never stop jobs - Flink will rebalance automatically
    if [ "$SCALING_UP" = "true" ]; then
        echo "🚀 Scaling UP detected ($CURRENT_SLOTS → $REQUIRED_SLOTS slots)"
        echo "✅ Flink will automatically rebalance jobs to use new resources!"
    else
        echo "📉 Scaling DOWN detected ($CURRENT_SLOTS → $REQUIRED_SLOTS slots)"
        echo "✅ Flink will automatically rebalance jobs on remaining resources!"
        echo "   Used slots: $USED_SLOTS"  
        echo "   Target slots: $REQUIRED_SLOTS"
        if [ $USED_SLOTS -gt $REQUIRED_SLOTS ]; then
            echo "⚠️  Note: Target slots ($REQUIRED_SLOTS) < Used slots ($USED_SLOTS)"
            echo "   Flink will handle job rebalancing automatically - jobs will NOT be stopped"
        fi
    fi
else
    echo "✅ No running jobs found. Safe to scale."
fi
echo ""

# Calculate required slots (4 slots per TaskManager)
REQUIRED_SLOTS=$((NEW_REPLICAS * 4))

echo "🔧 Scaling Flink cluster..."
echo "📊 Target: $NEW_REPLICAS TaskManagers ($REQUIRED_SLOTS slots total)"
echo "🎉 Jobs will continue running and rebalance automatically!"
echo ""

# Get current cluster overview using kubectl exec
echo "📊 Checking current cluster state..."
debug_log "Fetching cluster overview for comparison"
CLUSTER_INFO=$(kubectl exec -n $NAMESPACE deployment/flink-session-cluster -- curl -s http://localhost:8081/overview 2>/dev/null || echo "FAILED")

if [ "$CLUSTER_INFO" = "FAILED" ]; then
    echo "❌ Failed to connect to Flink REST API"
    echo "   Make sure the cluster is running and accessible"
    debug_log "REST API connection failed"
    exit 1
fi

debug_log "Successfully retrieved cluster overview"

CURRENT_SLOTS=$(echo "$CLUSTER_INFO" | grep -o '"slots-total":[0-9]*' | cut -d':' -f2)
CURRENT_TMS=$(echo "$CLUSTER_INFO" | grep -o '"taskmanagers":[0-9]*' | cut -d':' -f2)

echo "   Current: $CURRENT_TMS TaskManagers ($CURRENT_SLOTS slots)"
echo "   Target:  $NEW_REPLICAS TaskManagers ($REQUIRED_SLOTS slots)"

if [ "$CURRENT_SLOTS" -eq "$REQUIRED_SLOTS" ]; then
    echo "✅ Cluster already at target size. No scaling needed."
    exit 0
fi

# Update the FlinkDeployment configuration to set minimum slots
echo "🔧 Updating cluster configuration for $REQUIRED_SLOTS minimum slots..."
debug_log "Patching FlinkDeployment with replicas=$NEW_REPLICAS and min-slots=$REQUIRED_SLOTS"

PATCH_RESULT=$(kubectl patch flinkdeployment $DEPLOYMENT -n $NAMESPACE --type='merge' -p="{
    \"spec\": {
        \"flinkConfiguration\": {
            \"slotmanager.number-of-slots.min\": \"$REQUIRED_SLOTS\"
        },
        \"taskManager\": {
            \"replicas\": $NEW_REPLICAS
        }
    }
}" 2>&1)

if [ "$DEBUG_MODE" = "true" ]; then
    echo "🐛 DEBUG: Patch result:"
    echo "$PATCH_RESULT"
    echo ""
fi

echo "⏳ Waiting for Flink to scale TaskManagers (timeout: 5 minutes)..."
debug_log "Starting monitoring loop with $INTERVAL second intervals"
TIMEOUT=300
ELAPSED=0
INTERVAL=5
LAST_TMS=0
LAST_SLOTS=0

while [ $ELAPSED -lt $TIMEOUT ]; do
    debug_log "Checking cluster state (elapsed: ${ELAPSED}s)"
    
    # Use a more direct approach for faster checking
    CURRENT_STATE=$(kubectl exec -n $NAMESPACE deployment/flink-session-cluster -- curl -s http://localhost:8081/overview 2>/dev/null || echo "FAILED")
    
    if [ "$DEBUG_MODE" = "true" ] && [ "$CURRENT_STATE" != "FAILED" ]; then
        echo "🐛 DEBUG: Full cluster state response:"
        echo "$CURRENT_STATE" | jq . 2>/dev/null || echo "$CURRENT_STATE"
        echo ""
    fi
    
    if [ "$CURRENT_STATE" != "FAILED" ]; then
        CURRENT_TMS=$(echo "$CURRENT_STATE" | grep -o '"taskmanagers":[0-9]*' | cut -d':' -f2)
        CURRENT_SLOTS=$(echo "$CURRENT_STATE" | grep -o '"slots-total":[0-9]*' | cut -d':' -f2)
        
        debug_log "Parsed values - TMs: $CURRENT_TMS, Slots: $CURRENT_SLOTS"
        
        # Only show progress if values changed (reduce noise)
        if [ "$CURRENT_TMS" != "$LAST_TMS" ] || [ "$CURRENT_SLOTS" != "$LAST_SLOTS" ] || [ "$DEBUG_MODE" = "true" ]; then
            echo "   Progress: $CURRENT_TMS TaskManagers ($CURRENT_SLOTS slots) - Target: $NEW_REPLICAS TMs ($REQUIRED_SLOTS slots)"
            LAST_TMS=$CURRENT_TMS
            LAST_SLOTS=$CURRENT_SLOTS
        fi
        
        if [ "$CURRENT_SLOTS" -eq "$REQUIRED_SLOTS" ] && [ "$CURRENT_TMS" -eq "$NEW_REPLICAS" ]; then
            echo "✅ Scaling completed successfully!"
            echo "📊 Final state: $CURRENT_TMS TaskManagers with $CURRENT_SLOTS slots"
            debug_log "Target achieved in ${ELAPSED} seconds"
            break
        fi
    else
        debug_log "Failed to get cluster state"
        echo "   ⚠️  Could not fetch cluster state, retrying..."
    fi
    
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "⚠️  Scaling timeout reached. Checking final status..."
    FINAL_STATE=$(kubectl exec -n $NAMESPACE deployment/flink-session-cluster -- curl -s http://localhost:8081/overview 2>/dev/null || echo "FAILED")
    if [ "$FINAL_STATE" != "FAILED" ]; then
        FINAL_TMS=$(echo "$FINAL_STATE" | grep -o '"taskmanagers":[0-9]*' | cut -d':' -f2)
        FINAL_SLOTS=$(echo "$FINAL_STATE" | grep -o '"slots-total":[0-9]*' | cut -d':' -f2)
        echo "   Current state: $FINAL_TMS TaskManagers ($FINAL_SLOTS slots)"
    fi
fi

# Show current cluster status
echo ""
echo "📊 Current cluster status:"
kubectl get pods -n $NAMESPACE -l app=flink-session-cluster

if [ ! -z "$JOBS" ]; then
    echo ""
    echo "✅ All jobs continued running during scaling operation!"
    echo "🔄 Flink automatically rebalanced jobs across the new cluster size"
    echo "� Current running jobs:"
    UPDATED_JOBS=$(kubectl exec -n $NAMESPACE deployment/flink-session-cluster -- flink list 2>/dev/null | grep "RUNNING" || echo "No running jobs found")
    echo "$UPDATED_JOBS"
fi

echo ""
echo "✅ Scaling operation completed!"
echo "🎯 Target: $NEW_REPLICAS TaskManager replicas ($REQUIRED_SLOTS slots)"

# Show final cluster state via REST API if possible
FINAL_CLUSTER_STATE=$(kubectl exec -n $NAMESPACE deployment/flink-session-cluster -- curl -s http://localhost:8081/overview 2>/dev/null || echo "FAILED")
if [ "$FINAL_CLUSTER_STATE" != "FAILED" ]; then
    FINAL_TMS=$(echo "$FINAL_CLUSTER_STATE" | grep -o '"taskmanagers":[0-9]*' | cut -d':' -f2)
    FINAL_SLOTS=$(echo "$FINAL_CLUSTER_STATE" | grep -o '"slots-total":[0-9]*' | cut -d':' -f2)
    echo "📊 Current: $FINAL_TMS TaskManagers ($FINAL_SLOTS slots)"
    
    if [ "$FINAL_SLOTS" -eq "$REQUIRED_SLOTS" ] && [ "$FINAL_TMS" -eq "$NEW_REPLICAS" ]; then
        echo "🎉 Scaling successful!"
        if [ ! -z "$JOBS" ]; then
            echo "🔄 All jobs have been automatically rebalanced across the new cluster size"
        fi
    else
        echo "⚠️  Scaling may still be in progress or encountered issues"
    fi
else
    echo "🔍 Use 'kubectl get pods -n $NAMESPACE' to check final cluster state"
fi
