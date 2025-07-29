#!/bin/bash

# Flink Platform Cleanup Script
# This script removes the entire Flink platform deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "Starting Flink Platform cleanup..."

# Remove Network Policies
print_status "Removing Network Policies..."
kubectl delete -f manifests/06-network-policies.yaml --ignore-not-found=true

# Remove Flink SQL Gateway
print_status "Removing Flink SQL Gateway..."
kubectl delete -f manifests/04-flink-sql-gateway.yaml --ignore-not-found=true

# Remove Flink Session Cluster
print_status "Removing Flink Session Cluster..."
kubectl delete -f manifests/03-flink-session-cluster-gcp.yaml --ignore-not-found=true
kubectl delete -f manifests/03-flink-session-cluster-aks.yaml --ignore-not-found=true

# Remove storage, RBAC, and quotas
print_status "Removing RBAC and resource quotas..."
kubectl delete -f manifests/05-resource-quotas.yaml --ignore-not-found=true
kubectl delete -f manifests/02-rbac-gcp.yaml --ignore-not-found=true
kubectl delete -f manifests/02-rbac-aks.yaml --ignore-not-found=true

# Remove namespace (this will clean up any remaining resources)
print_status "Removing namespace..."
kubectl delete -f manifests/01-namespace.yaml --ignore-not-found=true

print_status "Cleanup completed!"
print_warning "Note: The Flink Kubernetes Operator is still installed in the flink-system namespace."
print_warning "To remove it completely, run: helm uninstall flink-kubernetes-operator -n flink-system"
print_status "The Custom SQL Executor (CLI tool) does not require cleanup as it's not deployed as a Kubernetes resource."
