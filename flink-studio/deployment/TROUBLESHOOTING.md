# Flink Studio Deployment Troubleshooting Guide

This guide helps resolve common issues encountered during Flink Studio deployment and operation.

## Pre-Deployment Issues

### 1. Kubernetes Connectivity Issues
**Symptoms:**
- `kubectl cluster-info` fails
- `kubectl get nodes` returns errors

**Solutions:**
```bash
# Check cluster context
kubectl config current-context

# List available contexts
kubectl config get-contexts

# Switch to correct context
kubectl config use-context YOUR_CLUSTER_CONTEXT

# For GKE
gcloud container clusters get-credentials CLUSTER_NAME --zone=ZONE --project=PROJECT_ID

# For AKS
az aks get-credentials --resource-group RESOURCE_GROUP --name CLUSTER_NAME
```

### 2. Insufficient Cluster Resources
**Symptoms:**
- Pods stuck in `Pending` state
- `kubectl describe pod` shows "Insufficient cpu" or "Insufficient memory"

**Solutions:**
```bash
# Check node resources
kubectl describe nodes

# Check resource quotas
kubectl describe resourcequota -n flink-studio

# Scale up cluster if needed (cloud-specific commands)
# GKE: gcloud container clusters resize CLUSTER_NAME --num-nodes=NEW_SIZE
# AKS: az aks scale --resource-group RG --name CLUSTER --node-count NEW_SIZE
```

### 3. Storage Class Issues
**Symptoms:**
- PVCs stuck in `Pending` state
- "no persistent volumes available" errors

**Solutions:**
```bash
# List available storage classes
kubectl get storageclass

# Check PVC status (minimal storage requirements now)
kubectl get pvc -n flink-studio

# For GCP: Ensure GKE has persistent disk CSI driver enabled
# For Azure: Ensure AKS has managed disk CSI driver enabled
```

## Deployment Issues

### 1. Flink Kubernetes Operator Installation Fails
**Symptoms:**
- Helm install fails
- Operator pods not starting

**Solutions:**
```bash
# Check Helm repository
helm repo list | grep flink

# Update Helm repository
helm repo update

# Check operator logs
kubectl logs -n flink-system deployment/flink-kubernetes-operator

# Reinstall operator
helm uninstall flink-kubernetes-operator -n flink-system
helm install flink-kubernetes-operator flink-operator-repo/flink-kubernetes-operator \
    --namespace flink-system \
    --create-namespace
```

### 2. FlinkDeployment Not Ready
**Symptoms:**
- `kubectl get flinkdeployment` shows `NOT_READY`
- Flink cluster pods not starting

**Solutions:**
```bash
# Check FlinkDeployment status
kubectl describe flinkdeployment flink-session-cluster -n flink-studio

# Check operator logs
kubectl logs -n flink-system deployment/flink-kubernetes-operator

# Check Flink JobManager logs
kubectl logs -n flink-studio deployment/flink-session-cluster

# Verify service account permissions
kubectl auth can-i create pods --as=system:serviceaccount:flink-studio:flink -n flink-studio

# Common fixes:
# 1. Check image availability
# 2. Verify cloud storage access
# 3. Check resource limits
```

### 3. Image Pull Errors
**Symptoms:**
- `ImagePullBackOff` or `ErrImagePull` status
- Cannot pull custom Docker images

**Solutions:**
```bash
# Check image availability (now using default Docker Hub images)
docker pull flink:2.0.0-scala_2.12-java21  # Default Flink image for both GCP and Azure

# No additional authentication needed for Docker Hub public images
# Custom cloud configurations are handled via ConfigMaps and environment variables

# Check if pods can pull the image
kubectl describe pod POD_NAME -n flink-studio
```

### 4. Azure Storage Secret Issues
**Symptoms:**
- Azure deployment fails with storage access errors
- "storage-account-key" not found errors

**Solutions:**
```bash
# Create the required secret
kubectl create secret generic azure-storage-secret \
  --from-literal=storage-account-key=YOUR_ACTUAL_STORAGE_ACCOUNT_KEY \
  -n flink-studio

# Verify secret exists
kubectl get secret azure-storage-secret -n flink-studio -o yaml

# Get storage account key from Azure
az storage account keys list --account-name sbxstagflinkstorage --resource-group YOUR_RG
```

## Runtime Issues

### 1. SQL Gateway Connection Issues
**Symptoms:**
- Custom SQL Executor cannot connect to Flink SQL Gateway
- Gateway returns connection errors
- Timeout errors during SQL execution

**Solutions:**
```bash
# Check SQL Gateway logs
kubectl logs deployment/flink-sql-gateway -n flink-studio

# Verify gateway is running
kubectl get pods -n flink-studio -l app.kubernetes.io/name=flink-sql-gateway

# Test gateway endpoint directly
kubectl port-forward svc/flink-sql-gateway 8083:8083 -n flink-studio
curl http://localhost:8083/v1/info

# Check network policies
kubectl get networkpolicy -n flink-studio
kubectl describe networkpolicy flink-sql-gateway-policy -n flink-studio

# Verify Flink cluster is accessible from gateway
kubectl exec -it deployment/flink-sql-gateway -n flink-studio -- \
  curl http://flink-session-cluster-rest:8081/overview
```

### 2. Custom SQL Executor Issues
**Symptoms:**
- SQL executor cannot connect to Flink SQL Gateway
- Connection timeout errors
- Invalid response errors

**Solutions:**
```bash
# Test SQL Gateway connectivity
curl http://localhost:8083/v1/info

# Check if port-forward is running
kubectl port-forward svc/flink-sql-gateway 8083:8083 -n flink-studio

# Test with verbose logging
python flink_sql_executor.py --sql "SELECT 1" --log-level DEBUG

# Check configuration
cat config.yaml

# Verify SQL Gateway is responding
kubectl logs deployment/flink-sql-gateway -n flink-studio
```

### 3. Flink Job Failures
**Symptoms:**
- SQL queries fail or timeout
- Jobs show FAILED status in Flink UI

**Solutions:**
```bash
# Check Flink JobManager logs
kubectl logs -n flink-studio deployment/flink-session-cluster

# Check TaskManager logs
kubectl logs -n flink-studio -l component=taskmanager

# Access Flink Web UI
kubectl port-forward svc/flink-session-cluster-rest 8081:8081 -n flink-studio
# Then access http://localhost:8081

# Check cloud storage access
# For GCP: Verify Workload Identity setup
# For Azure: Verify storage account key is correct

# Check resource allocation
kubectl top pods -n flink-studio
```

### 4. Network Policy Issues
**Symptoms:**
- Components cannot communicate
- Timeout errors between services

**Solutions:**
```bash
# List network policies
kubectl get networkpolicy -n flink-studio

# Temporarily disable network policies for testing
kubectl delete networkpolicy --all -n flink-studio

# Test connectivity from within the cluster
kubectl exec -it deployment/flink-sql-gateway -n flink-studio -- \
  curl http://flink-session-cluster-rest:8081/overview

# Re-apply network policies after testing
kubectl apply -f manifests/06-network-policies.yaml
```

## Cloud-Specific Issues

### GCP Issues

#### Workload Identity Problems
```bash
# Check service account annotation
kubectl get serviceaccount flink -n flink-studio -o yaml

# Verify Google Service Account exists
gcloud iam service-accounts describe flink-gcs@sbx-stag.iam.gserviceaccount.com

# Check IAM binding
gcloud iam service-accounts get-iam-policy flink-gcs@sbx-stag.iam.gserviceaccount.com

# Fix binding if needed
gcloud iam service-accounts add-iam-policy-binding \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:sbx-stag.svc.id.goog[flink-studio/flink]" \
  flink-gcs@sbx-stag.iam.gserviceaccount.com
```

#### GCS Access Issues
```bash
# Test GCS access from pod
kubectl exec -it deployment/flink-session-cluster -n flink-studio -- \
  gsutil ls gs://sbx-stag-flink-storage/

# Check bucket permissions
gsutil iam get gs://sbx-stag-flink-storage/

# Grant required permissions
gsutil iam ch serviceAccount:flink-gcs@sbx-stag.iam.gserviceaccount.com:roles/storage.admin \
  gs://sbx-stag-flink-storage/
```

### Azure Issues

#### Storage Account Access
```bash
# Test storage access from pod
kubectl exec -it deployment/flink-session-cluster -n flink-studio -- \
  env | grep AZURE_STORAGE

# Verify storage account exists
az storage account show --name sbxstagflinkstorage --resource-group YOUR_RG

# Test connectivity to storage
az storage blob list --account-name sbxstagflinkstorage --container-name flink
```

## Monitoring and Debugging

### Useful Commands
```bash
# Get overall cluster status
kubectl get all -n flink-studio

# Check events for issues
kubectl get events -n flink-studio --sort-by='.lastTimestamp'

# Monitor resource usage
kubectl top pods -n flink-studio
kubectl top nodes

# Check logs for all components
kubectl logs -n flink-studio deployment/flink-session-cluster
kubectl logs -n flink-studio deployment/flink-sql-gateway

# Port forward for local access
kubectl port-forward svc/flink-session-cluster-rest 8081:8081 -n flink-studio &
kubectl port-forward svc/flink-sql-gateway 8083:8083 -n flink-studio &
```

### Clean Restart Procedure
If you need to completely restart the deployment:

```bash
# 1. Delete all resources
kubectl delete namespace flink-studio

# 2. Wait for namespace deletion
kubectl get namespaces | grep flink-studio

# 3. Redeploy
./deploy.sh
```

## Getting Help

1. **Check the logs** - Most issues can be diagnosed from component logs
2. **Verify prerequisites** - Run `./pre-deploy-check.sh` again
3. **Test connectivity** - Use port-forward to test individual components
4. **Check resource usage** - Ensure cluster has sufficient resources
5. **Review cloud-specific settings** - Verify storage and authentication setup

For persistent issues:
- Check Flink documentation: https://flink.apache.org/
- Check Kubernetes documentation: https://kubernetes.io/docs/
- Review cloud provider documentation (GCP/Azure)
