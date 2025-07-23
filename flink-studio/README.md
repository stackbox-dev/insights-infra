# Flink SQL Studio on Kubernetes - Deployment Guide

This repository contains the complete deployment manifests and instructions for setting up a robust, multi-user Flink SQL Studio on Kubernetes, as described in [ARCH.md](ARCH.md).

## Architecture Overview

The platform consists of four main components:

1. **Flink Kubernetes Operator**: Manages Flink cluster lifecycle
2. **Flink Session Cluster**: Long-running cluster for job execution
3. **Flink SQL Gateway**: REST API for SQL query submission
4. **Apache Hue**: Web-based SQL editor and interface

## Prerequisites

Before deploying the Flink platform, ensure you have:

### Required Tools
- `kubectl` (v1.24+) - configured to access your Kubernetes cluster
- `helm` (v3.8+) - for installing the Flink Kubernetes Operator
- A Kubernetes cluster with:
  - At least 8 CPU cores and 16GB RAM available
  - Storage provisioner (for PersistentVolumes)
  - Ingress controller (nginx recommended)

### Storage Requirements

**IMPORTANT**: This deployment requires `ReadWriteMany` (RWX) storage for Flink checkpoints and high availability.

#### Google Cloud Platform (GKE)
- **Required**: Google Filestore with CSI driver enabled
- **Storage Classes**: `standard-rwx` (Filestore Basic)
- **Setup**:
  ```bash
  # Enable Filestore CSI driver
  gcloud container clusters update CLUSTER_NAME \
      --update-addons=GcpFilestoreCsiDriver=ENABLED \
      --zone=ZONE
  ```

#### Microsoft Azure (AKS) - Coming Soon
- **Required**: Azure Files with Premium tier
- **Storage Classes**: `azurefile-csi-premium`
- **Setup**: (Implementation pending)

#### Storage Allocation
- **Checkpoints**: 75Gi (ReadWriteMany via Filestore)
- **Savepoints**: 150Gi (ReadWriteMany via Filestore)  
- **High Availability**: 5Gi (ReadWriteMany via Filestore)
- **Total Filestore**: ~230Gi minimum

### Required Kubernetes Resources
- **CPU**: Minimum 8 cores (recommended: 16+ cores)
- **Memory**: Minimum 16GB (recommended: 32+ GB)
- **Storage**: At least 50GB for persistent volumes
- **Network**: Ingress controller for external access

### Optional Components
- **Cert-Manager**: For automatic TLS certificate management
- **Monitoring**: Prometheus/Grafana for observability

## Quick Start

### 1. Clone and Navigate
```bash
cd flink-studio
```

### 2. Review Configuration
Before deployment, review and customize these files if needed:
- `manifests/03-flink-session-cluster.yaml` - Flink cluster resources
- `manifests/05-resource-quotas.yaml` - Resource limits
- `manifests/08-hue.yaml` - Hue ingress hostname
- `helm/hue-values.yaml` - Hue configuration (if using Helm)

### 3. Deploy the Platform
Run the automated deployment script:
```bash
./deploy.sh
```

The script will:
1. Install the Flink Kubernetes Operator
2. Create the platform namespace and RBAC
3. Deploy persistent storage
4. Deploy the Flink Session Cluster
5. Deploy the Flink SQL Gateway
6. Deploy Apache Hue with configuration
7. Apply security policies

### 4. Verify Deployment
Check that all components are running:
```bash
kubectl get pods -n flink-studio
kubectl get svc -n flink-studio
kubectl get ingress -n flink-studio
```

Expected output should show all pods in `Running` status.

## Manual Deployment (Step-by-Step)

If you prefer to deploy manually or want to understand each step:

### Step 1: Install Flink Kubernetes Operator
```bash
# Add Flink operator Helm repository
helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.7.0/
helm repo update

# Install the operator
kubectl create namespace flink-system
helm install flink-kubernetes-operator flink-operator-repo/flink-kubernetes-operator \
    --namespace flink-system \
    --create-namespace
```

### Step 2: Deploy Core Infrastructure
```bash
# Create namespace and basic resources
kubectl apply -f manifests/01-namespace.yaml
kubectl apply -f manifests/02-rbac.yaml
kubectl apply -f manifests/02-storage.yaml
kubectl apply -f manifests/05-resource-quotas.yaml
```

### Step 3: Deploy Flink Session Cluster
```bash
kubectl apply -f manifests/03-flink-session-cluster.yaml

# Wait for cluster to be ready
kubectl wait --for=condition=Ready flinkdeployment/flink-session-cluster -n flink-studio --timeout=300s
```

### Step 4: Deploy SQL Gateway
```bash
kubectl apply -f manifests/04-flink-sql-gateway.yaml

# Wait for gateway to be ready
kubectl wait --for=condition=Available deployment/flink-sql-gateway -n flink-studio --timeout=180s
```

### Step 5: Deploy Apache Hue
```bash
kubectl apply -f manifests/07-hue-config.yaml
kubectl apply -f manifests/08-hue.yaml

# Wait for Hue to be ready
kubectl wait --for=condition=Available deployment/hue -n flink-studio --timeout=300s
```

### Step 6: Apply Security Policies (Optional)
```bash
kubectl apply -f manifests/06-network-policies.yaml
```

## Accessing the Platform

### Port Forwarding (Development)
For local development or testing:

```bash
# Flink Web UI
kubectl port-forward svc/flink-session-cluster-rest 8081:8081 -n flink-studio

# Hue Web Interface
kubectl port-forward svc/hue 8888:8888 -n flink-studio

# SQL Gateway API (direct access)
kubectl port-forward svc/flink-sql-gateway 8083:8083 -n flink-studio
```

Then access:
- **Flink UI**: http://localhost:8081
- **Hue Interface**: http://localhost:8888 (admin/admin)
- **SQL Gateway**: http://localhost:8083/v1/info

### Ingress (Production)
For production access via ingress:

1. **Update DNS/Hosts**: Point `hue.flink-studio.local` to your ingress controller IP
2. **Configure TLS**: Ensure cert-manager is installed for automatic certificates
3. **Access Hue**: https://hue.flink-studio.local

## Configuration

### Flink Cluster Scaling
Edit `manifests/03-flink-session-cluster.yaml` to adjust resources:

```yaml
jobManager:
  resource:
    memory: "2048m"  # Adjust as needed
    cpu: 1
  replicas: 2        # For high availability

taskManager:
  resource:
    memory: "4096m"  # Adjust as needed
    cpu: 2
  replicas: 3        # Scale based on workload
```

### Resource Quotas
Modify `manifests/05-resource-quotas.yaml` to set appropriate limits:

```yaml
spec:
  hard:
    requests.cpu: "20"      # Total CPU requests
    requests.memory: 40Gi   # Total memory requests
    limits.cpu: "40"        # Total CPU limits
    limits.memory: 80Gi     # Total memory limits
```

### Hue Configuration
Customize Hue settings in `manifests/07-hue-config.yaml`:

- Database backend (SQLite default, can use PostgreSQL/MySQL)
- Authentication method
- SQL Gateway connection settings
- UI customizations

## Using the Platform

### 1. Access Hue Interface
- Navigate to Hue web interface (localhost:8888 or via ingress)
- Login with default credentials: `admin/admin`

### 2. Create SQL Queries
- Click on "Query" in the top menu
- Select "Flink SQL" as the interpreter
- Write your Flink SQL queries

### 3. Example Queries
```sql
-- Create a table
CREATE TABLE example_table (
    id BIGINT,
    name STRING,
    age INT
) WITH (
    'connector' = 'datagen',
    'rows-per-second' = '1'
);

-- Query the table
SELECT * FROM example_table LIMIT 10;
```

## Monitoring and Troubleshooting

### Check Component Status
```bash
# Check all pods
kubectl get pods -n flink-studio

# Check Flink cluster status
kubectl get flinkdeployment -n flink-studio

# Check logs
kubectl logs deployment/flink-sql-gateway -n flink-studio
kubectl logs deployment/hue -n flink-studio
```

### Common Issues

#### 1. Flink Cluster Not Starting
- Check resource availability: `kubectl describe nodes`
- Verify PVC status: `kubectl get pvc -n flink-studio`
- Check operator logs: `kubectl logs -n flink-system deployment/flink-kubernetes-operator`

#### 2. SQL Gateway Connection Issues
- Verify Flink cluster is ready: `kubectl get flinkdeployment -n flink-studio`
- Check service endpoints: `kubectl get endpoints -n flink-studio`
- Test gateway directly: `curl http://localhost:8083/v1/info` (via port-forward)

#### 3. Hue Can't Connect to SQL Gateway
- Verify network policies allow traffic
- Check Hue configuration in ConfigMap
- Test connectivity from Hue pod:
  ```bash
  kubectl exec -it deployment/hue -n flink-studio -- curl http://flink-sql-gateway:8083/v1/info
  ```

### Performance Tuning

#### Flink Configuration
Adjust Flink settings in the FlinkDeployment manifest:
- Increase TaskManager slots for more parallelism
- Adjust memory settings based on workload
- Configure checkpointing and state backend

#### Resource Allocation
- Monitor resource usage: `kubectl top pods -n flink-studio`
- Adjust requests/limits based on actual usage
- Scale TaskManagers horizontally for larger workloads

## Security Considerations

### Production Hardening
1. **Change Default Credentials**: Update Hue admin password
2. **Enable TLS**: Configure proper TLS certificates
3. **Network Isolation**: Review and customize NetworkPolicies
4. **RBAC**: Implement fine-grained access controls
5. **Secret Management**: Use Kubernetes secrets for sensitive data

### Multi-tenancy
- Create separate namespaces for different teams
- Implement ResourceQuotas per namespace
- Use NetworkPolicies for traffic segregation
- Configure authentication/authorization in Hue

## Cleanup

To remove the entire platform:
```bash
./cleanup.sh
```

Or manually:
```bash
kubectl delete namespace flink-studio
helm uninstall flink-kubernetes-operator -n flink-system
kubectl delete namespace flink-system
```

## Troubleshooting Guide

### Deployment Issues
| Issue | Solution |
|-------|----------|
| Insufficient resources | Check cluster capacity with `kubectl describe nodes` |
| PVC binding issues | Verify storage class exists and has available storage |
| Image pull failures | Check internet connectivity and image availability |

### Runtime Issues
| Issue | Solution |
|-------|----------|
| Jobs fail to start | Check Flink logs and resource allocation |
| SQL queries timeout | Increase gateway timeout settings |
| Hue login issues | Verify Hue database and configuration |

## Contributing

When making changes to the platform:
1. Test changes in a development environment first
2. Update documentation if configuration changes
3. Validate all components work together after changes
4. Update version numbers in manifests if needed

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review Flink and Hue official documentation
3. Check Kubernetes events: `kubectl get events -n flink-studio`
4. Review component logs for error messages
