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
- `kubectl get flinkdeployment` shows lifecycle state other than `STABLE` or `DEPLOYED`
- Flink cluster pods not starting
- JobManager stuck in `Pending` or `CrashLoopBackOff`

**Solutions:**
```bash
# Check FlinkDeployment status (look for lifecycleState field)
kubectl describe flinkdeployment flink-session-cluster -n flink-studio
kubectl get flinkdeployment flink-session-cluster -n flink-studio -o jsonpath='{.status.lifecycleState}'

# Check operator logs
kubectl logs -n flink-system deployment/flink-kubernetes-operator --tail=100

# Check Flink JobManager logs
kubectl logs -n flink-studio deployment/flink-session-cluster --tail=100

# Verify service account has Workload Identity annotation
kubectl get serviceaccount flink -n flink-studio -o yaml

# For GCP: Check Workload Identity binding
gcloud iam service-accounts get-iam-policy flink-gcs@sbx-stag.iam.gserviceaccount.com

# For Azure: Check Managed Identity and federated credential
az identity show --name flink-identity --resource-group UnileverSBXWMS_2
az identity federated-credential list --identity-name flink-identity --resource-group UnileverSBXWMS_2

# Common fixes:
# 1. Verify custom image is accessible: asia-docker.pkg.dev/sbx-ci-cd/public/flink:2.0.0
# 2. Verify cloud storage access (GCS bucket or Azure storage container)
# 3. Check Workload Identity setup
# 4. Check resource limits and node capacity
# 5. Verify Aiven credentials secret exists
```

### 3. Image Pull Errors
**Symptoms:**
- `ImagePullBackOff` or `ErrImagePull` status
- Cannot pull custom Flink image from Artifact Registry

**Solutions:**
```bash
# Verify the custom image exists and is accessible
# Image: asia-docker.pkg.dev/sbx-ci-cd/public/flink:2.0.0-scala_2.12-java21

# For GCP: Verify Artifact Registry permissions
gcloud artifacts repositories describe public \
  --location=asia \
  --project=sbx-ci-cd

# Check if pods can pull the image
kubectl describe pod POD_NAME -n flink-studio

# If image is not accessible, you may need to configure imagePullSecrets
# or ensure the cluster's service account has Artifact Registry Reader role
```

### 4. Aiven Kafka Credentials Issues
**Symptoms:**
- Deployment fails with "aiven-credentials secret not found"
- Kafka connection errors in Flink jobs
- SSL/TLS handshake failures

**Solutions:**
```bash
# Verify the secret exists
kubectl get secret aiven-credentials -n flink-studio

# Check secret has all required keys
kubectl get secret aiven-credentials -n flink-studio -o jsonpath='{.data}' | jq -r 'keys[]'

# Expected keys:
# - username
# - password
# - truststore-password
# - kafka.truststore.jks

# If secret is missing, run the setup script
./scripts/create-aiven-secret.sh

# Verify JKS truststore is valid
kubectl get secret aiven-credentials -n flink-studio -o jsonpath='{.data.kafka\.truststore\.jks}' | base64 -d > /tmp/test.jks
keytool -list -keystore /tmp/test.jks -storepass $(kubectl get secret aiven-credentials -n flink-studio -o jsonpath='{.data.truststore-password}' | base64 -d)
```

### 5. Azure Workload Identity Issues
**Symptoms:**
- Azure deployment fails with authentication errors
- Cannot access Azure Blob Storage
- "AADSTS" error codes in logs

**Solutions:**
```bash
# Verify Managed Identity exists and is configured
az identity show --name flink-identity --resource-group UnileverSBXWMS_2

# Get the Client ID
CLIENT_ID=$(az identity show --name flink-identity --resource-group UnileverSBXWMS_2 --query clientId -o tsv)
echo "Client ID: $CLIENT_ID"

# Verify federated credential exists and is correct
az identity federated-credential show \
  --identity-name flink-identity \
  --resource-group UnileverSBXWMS_2 \
  --name flink-federated-credential

# Verify Kubernetes ServiceAccount annotation
kubectl get serviceaccount flink -n flink-studio -o yaml | grep azure.workload.identity/client-id

# Verify storage role assignment
az role assignment list \
  --assignee $CLIENT_ID \
  --scope /subscriptions/<subscription-id>/resourceGroups/UnileverSBXWMS_2/providers/Microsoft.Storage/storageAccounts/sbxunileverflinkstorage1

# Test storage access from pod
kubectl exec -it deployment/flink-session-cluster -n flink-studio -- \
  az storage container list --account-name sbxunileverflinkstorage1 --auth-mode login
```

## Runtime Issues

### 1. SQL Gateway Connection Issues
**Symptoms:**
- Custom SQL Executor cannot connect to Flink SQL Gateway
- Gateway returns connection errors or timeouts
- Port forwarding fails

**Solutions:**
```bash
# Check SQL Gateway logs
kubectl logs deployment/flink-sql-gateway -n flink-studio --tail=100

# Verify gateway is running
kubectl get pods -n flink-studio -l app=flink-sql-gateway

# Check gateway service
kubectl get svc flink-sql-gateway -n flink-studio
kubectl describe svc flink-sql-gateway -n flink-studio

# Test gateway endpoint with port-forward (service port is 80, not 8083)
kubectl port-forward svc/flink-sql-gateway 8083:80 -n flink-studio
curl http://localhost:8083/v1/info

# Verify Flink cluster is accessible from gateway
kubectl exec -it deployment/flink-sql-gateway -n flink-studio -- \
  curl http://flink-session-cluster:80/overview

# Check network policies are not blocking traffic
kubectl get networkpolicy -n flink-studio
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
- SQL queries fail with errors
- Jobs show FAILED status in Flink UI
- Checkpoint/savepoint failures
- Kafka connectivity errors

**Solutions:**
```bash
# Check Flink JobManager logs
kubectl logs -n flink-studio deployment/flink-session-cluster --tail=200

# Check TaskManager logs
kubectl logs -n flink-studio -l component=taskmanager --tail=200

# Access Flink Web UI (service port is 80, not 8081)
kubectl port-forward svc/flink-session-cluster 8081:80 -n flink-studio
# Then access http://localhost:8081

# Check cloud storage access
# For GCP: Test GCS access
kubectl exec -it deployment/flink-session-cluster -n flink-studio -- \
  gsutil ls gs://sbx-stag-flink-storage/

# For Azure: Test Azure Blob Storage access
kubectl exec -it deployment/flink-session-cluster -n flink-studio -- \
  az storage container list --account-name sbxunileverflinkstorage1 --auth-mode login

# Verify Aiven Kafka credentials are mounted
kubectl exec -it deployment/flink-session-cluster -n flink-studio -- \
  ls -la /opt/flink/secrets/

# Check resource allocation
kubectl top pods -n flink-studio

# Check for RocksDB issues (Azure only)
kubectl exec -it deployment/flink-session-cluster -n flink-studio -- \
  df -h /data/flink-rocksdb
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
kubectl get serviceaccount flink -n flink-studio -o yaml | grep iam.gke.io

# Expected annotation:
# iam.gke.io/gcp-service-account: flink-gcs@sbx-stag.iam.gserviceaccount.com

# Verify Google Service Account exists
gcloud iam service-accounts describe flink-gcs@sbx-stag.iam.gserviceaccount.com

# Check IAM binding (Workload Identity User)
gcloud iam service-accounts get-iam-policy flink-gcs@sbx-stag.iam.gserviceaccount.com

# Expected binding:
# members:
#   - serviceAccount:sbx-stag.svc.id.goog[flink-studio/flink]
# role: roles/iam.workloadIdentityUser

# Fix binding if missing
gcloud iam service-accounts add-iam-policy-binding \
  flink-gcs@sbx-stag.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:sbx-stag.svc.id.goog[flink-studio/flink]"

# Test authentication from pod
kubectl exec -it deployment/flink-session-cluster -n flink-studio -- gcloud auth list
```

#### GCS Access Issues
```bash
# Test GCS access from pod
kubectl exec -it deployment/flink-session-cluster -n flink-studio -- \
  gsutil ls gs://sbx-stag-flink-storage/

# Check bucket permissions
gsutil iam get gs://sbx-stag-flink-storage/

# Verify service account has Storage Admin role
gsutil iam ch serviceAccount:flink-gcs@sbx-stag.iam.gserviceaccount.com:roles/storage.admin \
  gs://sbx-stag-flink-storage/

# Check for checkpoint/savepoint directories
kubectl exec -it deployment/flink-session-cluster -n flink-studio -- \
  gsutil ls gs://sbx-stag-flink-storage/flink-checkpoints/
```

### Azure Issues

#### Workload Identity Problems
```bash
# Check service account labels and annotations
kubectl get serviceaccount flink -n flink-studio -o yaml

# Expected annotation and label:
# annotations:
#   azure.workload.identity/client-id: 911d60a1-3770-40cb-978b-8b7342bf02b8
# labels:
#   azure.workload.identity/use: "true"

# Verify Managed Identity exists
az identity show --name flink-identity --resource-group UnileverSBXWMS_2

# Verify federated credential is configured correctly
az identity federated-credential show \
  --identity-name flink-identity \
  --resource-group UnileverSBXWMS_2 \
  --name flink-federated-credential

# Expected output should include:
# issuer: https://centralindia.oic.prod-aks.azure.com/<tenant-id>/<issuer-id>/
# subject: system:serviceaccount:flink-studio:flink

# Test authentication from pod
kubectl exec -it deployment/flink-session-cluster -n flink-studio -- \
  env | grep AZURE_
```

#### Storage Account Access
```bash
# Verify environment-specific storage account name
# sbx-uat: sbxunileverflinkstorage1
# samadhan-prod: Different storage account

# Test storage access from pod (using Workload Identity)
kubectl exec -it deployment/flink-session-cluster -n flink-studio -- \
  az storage container list --account-name sbxunileverflinkstorage1 --auth-mode login

# Verify storage account exists
az storage account show --name sbxunileverflinkstorage1 --resource-group UnileverSBXWMS_2

# Check if container exists
az storage container show \
  --name flink \
  --account-name sbxunileverflinkstorage1 \
  --auth-mode login

# Verify role assignment (Storage Blob Data Contributor)
CLIENT_ID=$(az identity show --name flink-identity --resource-group UnileverSBXWMS_2 --query clientId -o tsv)
az role assignment list \
  --assignee $CLIENT_ID \
  --scope /subscriptions/<subscription-id>/resourceGroups/UnileverSBXWMS_2/providers/Microsoft.Storage/storageAccounts/sbxunileverflinkstorage1

# Check for checkpoint/savepoint directories
kubectl exec -it deployment/flink-session-cluster -n flink-studio -- \
  az storage blob list \
  --container-name flink \
  --account-name sbxunileverflinkstorage1 \
  --auth-mode login \
  --prefix flink-checkpoints/
```

## Monitoring and Debugging

### Useful Commands
```bash
# Get overall cluster status
kubectl get all -n flink-studio

# Check FlinkDeployment resource status
kubectl get flinkdeployment -n flink-studio
kubectl describe flinkdeployment flink-session-cluster -n flink-studio

# Check events for issues
kubectl get events -n flink-studio --sort-by='.lastTimestamp'

# Monitor resource usage
kubectl top pods -n flink-studio
kubectl top nodes

# Check logs for all components
kubectl logs -n flink-studio deployment/flink-session-cluster --tail=100
kubectl logs -n flink-studio deployment/flink-sql-gateway --tail=100
kubectl logs -n flink-studio -l component=taskmanager --tail=100

# Check Flink Kubernetes Operator logs
kubectl logs -n flink-system deployment/flink-kubernetes-operator --tail=100

# Port forward for local access (note: service ports are 80, not 8081/8083)
kubectl port-forward svc/flink-session-cluster 8081:80 -n flink-studio &
kubectl port-forward svc/flink-sql-gateway 8083:80 -n flink-studio &

# Verify secrets
kubectl get secret aiven-credentials -n flink-studio
kubectl get secret -n flink-studio

# Check Workload Identity configuration
kubectl get serviceaccount flink -n flink-studio -o yaml
```

### Clean Restart Procedure
If you need to completely restart the deployment:

```bash
# 1. Use the cleanup script
./scripts/cleanup.sh

# OR manually delete resources
kubectl delete namespace flink-studio

# 2. Wait for namespace deletion
kubectl get namespaces | grep flink-studio

# 3. Redeploy
./scripts/deploy.sh
```

## Common Error Messages

### "aiven-credentials secret not found"
- **Cause**: The Aiven Kafka credentials secret is missing
- **Solution**: Run `./scripts/create-aiven-secret.sh` to create the secret

### "ImagePullBackOff" for custom Flink image
- **Cause**: Cannot pull from Artifact Registry
- **Solution**: Verify image exists and cluster has access to `asia-docker.pkg.dev/sbx-ci-cd/public/`

### "Lifecycle state: ERROR" in FlinkDeployment
- **Cause**: Cloud storage access issues or resource constraints
- **Solution**: Check operator logs and verify Workload Identity setup

### "Connection refused" to Flink SQL Gateway
- **Cause**: Service not ready or incorrect port mapping
- **Solution**: Use port 80 for services, not 8083. Port forward: `kubectl port-forward svc/flink-sql-gateway 8083:80`

### Checkpoint failures with GCS/Azure errors
- **Cause**: Workload Identity not configured correctly
- **Solution**: Verify service account annotations and cloud IAM bindings

## Getting Help

1. **Check the logs** - Most issues can be diagnosed from component logs:
   - JobManager: `kubectl logs deployment/flink-session-cluster -n flink-studio`
   - SQL Gateway: `kubectl logs deployment/flink-sql-gateway -n flink-studio`
   - Operator: `kubectl logs deployment/flink-kubernetes-operator -n flink-system`

2. **Verify prerequisites** - Run `./scripts/pre-deploy-check.sh` again

3. **Test connectivity** - Use port-forward to test individual components

4. **Check resource usage** - Ensure cluster has sufficient resources

5. **Review cloud-specific settings** - Verify storage and Workload Identity setup

6. **Check Aiven credentials** - Verify the secret exists and has all required keys

For persistent issues:
- Check Flink documentation: https://flink.apache.org/
- Check Flink Kubernetes Operator docs: https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-stable/
- Review cloud provider documentation (GCP/Azure)
- Check Aiven documentation: https://aiven.io/docs/
