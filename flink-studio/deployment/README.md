# Flink SQL Studio on Kubernetes - Deployment Guide

This repository contains the complete deployment manifests and instructions for setting up a robust, multi-user Flink SQL Studio on Kubernetes, as described in [ARCH.md](ARCH.md).

## Quick Links

- 📚 [Architecture Overview](ARCH.md) - System design and components
- 🔧 [Troubleshooting Guide](TROUBLESHOOTING.md) - Common issues and solutions
- 🚀 [Scaling Guide](#scaling-your-flink-cluster) - How to scale TaskManagers safely

## Architecture Overview

The platform consists of three main components:

1. **Flink Kubernetes Operator**: Manages Flink cluster lifecycle
2. **Flink Session Cluster**: Long-running cluster for job execution with comprehensive connector support
3. **Flink SQL Gateway**: REST API for SQL query submission
4. **Custom SQL Executor**: Command-line tool for executing Flink SQL queries

### Supported Connectors & Libraries

The Flink deployment includes the following pre-installed connectors and libraries:

#### Core Connectors

- **Kafka Connector** (`flink-sql-connector-kafka-4.0.0-2.0.jar`) - 9.7MB
  - Full Apache Kafka integration for streaming data
  - Supports SASL/SSL authentication for Kafka services
  - Compatible with Confluent, Azure Event Hubs, and Aiven Kafka

#### Data Formats & Serialization

- **Avro Connector** (`flink-sql-avro-2.0.0.jar`) - 4.3MB
  - Native Avro schema support for structured data processing
  - Schema registry integration capabilities
  - Efficient binary serialization/deserialization

#### Cloud Authentication

- **Google Auth Library** (`google-auth-library-oauth2-http-1.19.0.jar`) - 247KB
  - OAuth2 authentication for GCP services
  - Required for GCP Workload Identity authentication
- **Google Cloud Core** (`google-cloud-core-2.8.1.jar`) - 131KB
  - Core GCP service integration libraries

#### File System Connectors

- **Google Cloud Storage (GCS)**: Native Hadoop filesystem support
- **Amazon S3**: Both Hadoop and Presto filesystem implementations
- **Azure Blob Storage**: Hadoop filesystem integration
- **Alibaba OSS**: Object storage support

All connectors are automatically downloaded and configured during deployment via init containers.

## Prerequisites

Before deploying the Flink platform, ensure you have:

### Required Tools

- `kubectl` (v1.24+) - configured to access your Kubernetes cluster
- `helm` (v3.8+) - for installing the Flink Kubernetes Operator
- A Kubernetes cluster with:
  - At least 6 CPU cores and 12GB RAM available
  - Ingress controller (nginx recommended)

### Cloud Storage Requirements

This deployment uses cloud-native storage solutions for Flink state management:

#### Google Cloud Platform (GKE)

- **Required**: Google Cloud Storage (GCS) bucket
- **Bucket**: `gs://sbx-stag-flink-storage/`
- **Authentication**: GKE Workload Identity
- **Setup**:

  ```bash
  # Create GCS bucket
  gsutil mb gs://sbx-stag-flink-storage/

  # Create Google Service Account
  gcloud iam service-accounts create flink-gcs --project=sbx-stag

  # Grant storage permissions
  gsutil iam ch serviceAccount:flink-gcs@sbx-stag.iam.gserviceaccount.com:roles/storage.admin \
    gs://sbx-stag-flink-storage/
  ```

#### Microsoft Azure (AKS)

- **Required**: Azure Blob Storage with Data Lake Gen2
- **Storage Account**: `sbxstagflinkstorage`
- **Container**: `flink`
- **Authentication**: Storage Account Key
- **Setup**:

  ```bash
  # Create storage account with hierarchical namespace
  az storage account create --name sbxstagflinkstorage \
    --resource-group YOUR_RG --location YOUR_LOCATION \
    --sku Standard_LRS --kind StorageV2 --hns true

  # Create container
  az storage container create --name flink --account-name sbxstagflinkstorage
  ```

#### Storage Usage

- **Checkpoints**: Stored directly in cloud storage (GCS/Azure Blob)
- **Savepoints**: Stored directly in cloud storage (GCS/Azure Blob)
- **High Availability**: Kubernetes-native HA with cloud storage backend
- **Local Storage**: Not required for Custom SQL Executor (CLI tool)

### Required Kubernetes Resources

- **CPU**: Minimum 6 cores (recommended: 12+ cores)
- **Memory**: Minimum 12GB (recommended: 24+ GB)
- **Storage**: None required (uses cloud storage directly)
- **Network**: Ingress controller for external access (optional)

### Optional Components

- **Cert-Manager**: For automatic TLS certificate management
- **Monitoring**: Prometheus/Grafana for observability

## Quick Start

### 1. Clone and Navigate

```bash
cd flink-studio
```

### 2. Pre-Deployment Validation (Recommended)

Run the comprehensive validation script to check all prerequisites:

```bash
./scripts/pre-deploy-check.sh
```

This validation script will check:

- Required tools (kubectl, helm, cloud CLI)
- Kubernetes cluster connectivity and resources
- Cloud-specific prerequisites (GCS bucket, Azure storage account)
- Storage configuration and permissions
- Network requirements and connectivity

**Important**: Address any issues found by the validation script before proceeding with deployment.

### 3. Review Configuration

Before deployment, review and customize these files if needed:

- `manifests/03-flink-session-cluster-gcp.yaml` or `manifests/03-flink-session-cluster-aks.yaml` - Flink cluster resources
- `manifests/05-resource-quotas.yaml` - Resource limits
- `manifests/08-hue.yaml` - Hue ingress hostname

### 4. Deploy the Platform

Run the automated deployment script:

```bash
./deploy.sh
```

The script will:

1. Install the Flink Kubernetes Operator
2. Create the platform namespace and RBAC
3. Deploy persistent storage (minimal configuration)
4. Deploy the Flink Session Cluster
5. Deploy the Flink SQL Gateway
6. Configure the Custom SQL Executor
7. Apply security policies

**Note:** For any deployment issues, refer to [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed solutions.

## Available Scripts

The `scripts/` directory contains utility scripts for managing the Flink deployment:

### Core Deployment Scripts

- **`deploy.sh`** - Automated deployment of the entire platform
- **`cleanup.sh`** - Complete cleanup of all deployed resources
- **`pre-deploy-check.sh`** - Comprehensive pre-deployment validation

### Management & Operations Scripts

- **`scale.sh`** - Safe scaling of TaskManager replicas with validation
- **`build-image.sh`** - Build custom Flink Docker images
- **`test-deployment.sh`** - Comprehensive deployment testing and validation
- **`test-kafka-connectivity.sh`** - Test Kafka connectivity and authentication
- **`get-state-size.sh`** - Monitor Flink job state sizes and performance

### Security & Configuration Scripts

None currently configured.

## Docker Files

The `docker/` directory contains Docker-related files for building custom Flink images:

- **`Dockerfile`** - Custom Flink image with pre-installed connectors
- **`prepare-image.sh`** - Image preparation script (used by Dockerfile)

### Building Custom Images

```bash
# Build custom Flink image with all connectors
./scripts/build-image.sh
```

### Usage Examples

```bash
# Pre-deployment validation
./scripts/pre-deploy-check.sh

# Deploy entire platform
./scripts/deploy.sh

# Scale TaskManagers safely
./scripts/scale.sh 6

# Test deployment health
./scripts/test-deployment.sh

# Monitor state sizes
./scripts/get-state-size.sh

# Clean up everything
./scripts/cleanup.sh
```

### 5. Verify Deployment

#### Quick Health Check

Use the comprehensive test script to validate the deployment:

```bash
# Quick validation of core components
./test-deployment.sh --quick

# Full comprehensive testing (recommended)
./test-deployment.sh

# Test only library presence
./test-deployment.sh --libs-only

# Test connectivity only
./test-deployment.sh --connectivity-only
```

The test script validates:

- ✅ **Deployment Status**: FlinkDeployment resource is STABLE
- ✅ **Pod Health**: All pods running and ready (JobManager + TaskManagers)
- ✅ **Init Containers**: Library downloads completed successfully
- ✅ **Library Validation**: All required connectors present in all pods
- ✅ **Flink UI**: Web interface accessible and responsive
- ✅ **TaskManager Connectivity**: All TaskManagers registered with JobManager
- ✅ **Avro Support**: Avro connector properly loaded

#### Manual Verification

Alternatively, check components manually:

```bash
# Check pod status
kubectl get pods -n flink-studio

# Expected output:
# NAME                                     READY   STATUS    RESTARTS   AGE
# flink-session-cluster-xxxxx              1/1     Running   0          5m
# flink-session-cluster-taskmanager-1-1    1/1     Running   0          5m
# flink-session-cluster-taskmanager-1-2    1/1     Running   0          5m
# flink-sql-gateway-xxxxx                  1/1     Running   0          5m
# hue-xxxxx                                1/1     Running   0          5m

# Check services and ingress
kubectl get svc -n flink-studio
kubectl get ingress -n flink-studio

# Verify libraries are loaded (optional)
kubectl exec -n flink-studio deployment/flink-session-cluster -- ls -la /opt/flink/lib/ | grep -E "(avro|kafka|google)"
```

Expected library output:

```
-rw-r--r-- 1 root root  4342426 Jul 25 07:28 flink-sql-avro-2.0.0.jar
-rw-r--r-- 1 root root  9765334 Jul 25 07:28 flink-sql-connector-kafka-2.0.0.jar
-rw-r--r-- 1 root root   247870 Jul 25 07:28 google-auth-library-oauth2-http-1.19.0.jar
-rw-r--r-- 1 root root   131444 Jul 25 07:28 google-cloud-core-2.8.1.jar
```

## Manual Deployment (Step-by-Step)

If you prefer to deploy manually or want to understand each step:

### Step 1: Install Flink Kubernetes Operator

```bash
# Add Flink operator Helm repository
helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.12.1/
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

# For GCP deployment
kubectl apply -f manifests/02-rbac-gcp.yaml
kubectl apply -f manifests/02-storage-gcp.yaml

# For Azure deployment
kubectl apply -f manifests/02-rbac-aks.yaml
kubectl apply -f manifests/02-storage-aks.yaml

# Apply resource quotas
kubectl apply -f manifests/05-resource-quotas.yaml
```

### Step 3: Deploy Flink Session Cluster

```bash
# For GCP deployment
kubectl apply -f manifests/03-flink-session-cluster-gcp.yaml

# For Azure deployment
kubectl apply -f manifests/03-flink-session-cluster-aks.yaml

# Wait for cluster to be ready
kubectl wait --for=condition=Ready flinkdeployment/flink-session-cluster -n flink-studio --timeout=600s
```

### Step 4: Deploy SQL Gateway

```bash
kubectl apply -f manifests/04-flink-sql-gateway.yaml

# Wait for gateway to be ready
kubectl wait --for=condition=Available deployment/flink-sql-gateway -n flink-studio --timeout=180s
```

### Step 5: Configure Custom SQL Executor

The Custom SQL Executor is a CLI tool that communicates directly with the Flink SQL Gateway. No additional Kubernetes deployment is required.

```bash
# The SQL executor is available in the sql-executor directory
cd ../sql-executor

# Install Python dependencies (if running locally)
pip install -r requirements.txt

# Configure the executor to connect to your Flink SQL Gateway
# Edit config.yaml to set the SQL Gateway URL
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

# SQL Gateway API (for Custom SQL Executor)
kubectl port-forward svc/flink-sql-gateway 8083:8083 -n flink-studio
```

Then access:

- **Flink UI**: http://localhost:8081
- **SQL Gateway**: http://localhost:8083/v1/info

### Using the Custom SQL Executor

```bash
# Execute SQL from a file
python flink_sql_executor.py --file /path/to/your/query.sql

# Execute inline SQL
python flink_sql_executor.py --sql "SELECT 1"

# Execute with custom SQL Gateway URL
python flink_sql_executor.py --sql "SELECT 1" --sql-gateway-url http://localhost:8083
```

### Ingress (Production)

For production access via ingress (optional):

1. **Configure TLS**: Ensure cert-manager is installed for automatic certificates
2. **Set up Ingress**: Configure ingress for the Flink UI if external access is needed

## Configuration

### Flink Cluster Scaling

We provide an automated scaling script for easy TaskManager replica management:

#### Quick Start with scale.sh

```bash
# Scale to 6 TaskManager replicas (GCP)
./scale.sh 6

# Scale to 8 TaskManager replicas on Azure
./scale.sh 8 aks

# Check current cluster status
./scale.sh --status

# Preview changes without applying (dry run)
./scale.sh --dry-run 6

# Get help and see all options
./scale.sh --help
```

#### Script Features

- ✅ **Safe scaling**: Validates inputs and resource requirements
- ✅ **Multi-environment**: Supports both GCP and AKS deployments
- ✅ **Kubernetes context verification**: Checks cluster connectivity and requires user confirmation
- ✅ **Resource calculation**: Shows memory/CPU requirements before scaling
- ✅ **Status monitoring**: Check current cluster state and pod status
- ✅ **Dry-run mode**: Preview changes without applying them
- ✅ **Interactive confirmation**: Prevents accidental scaling operations
- ✅ **Context safety**: Always confirms target cluster before operations

#### Manual Configuration (Advanced)

For manual configuration, edit the appropriate cluster manifest:

**For GCP**: `manifests/03-flink-session-cluster-gcp.yaml`
**For Azure**: `manifests/03-flink-session-cluster-aks.yaml`

```yaml
jobManager:
  resource:
    memory: "1536m" # Adjust as needed
    cpu: 1
  replicas: 1 # Single replica for cost efficiency

taskManager:
  resource:
    memory: "8192m" # 8Gi per TaskManager
    cpu: 2
  replicas: 4 # Scale based on workload (use scale.sh instead)
```

### Resource Quotas

Modify `manifests/05-resource-quotas.yaml` to set appropriate limits:

```yaml
spec:
  hard:
    requests.cpu: "12" # Total CPU requests
    requests.memory: 24Gi # Total memory requests
    limits.cpu: "24" # Total CPU limits
    limits.memory: 48Gi # Total memory limits
```

### Custom SQL Executor Configuration

The Custom SQL Executor can be configured via `config.yaml`:

```yaml
sql_gateway:
  url: "http://localhost:8083"  # Flink SQL Gateway URL
  
logging:
  level: "INFO"  # DEBUG, INFO, WARNING, ERROR
```

## Using the Platform

### 1. Execute SQL Files

```bash
# Execute SQL from a file
cd ../sql-executor
python flink_sql_executor.py --file /path/to/your/query.sql
```

### 2. Execute Inline SQL

```bash
# Execute inline SQL
python flink_sql_executor.py --sql "SELECT 1"

# Execute multiple statements
python flink_sql_executor.py --sql "CREATE TABLE test AS SELECT 1; SELECT * FROM test;"
```

### 3. Example Queries

#### Basic Data Generation and Processing

```sql
-- Create a simple data generation table
CREATE TABLE example_table (
    id BIGINT,
    name STRING,
    age INT,
    event_time TIMESTAMP(3),
    WATERMARK FOR event_time AS event_time - INTERVAL '1' SECOND
) WITH (
    'connector' = 'datagen',
    'rows-per-second' = '1',
    'fields.id.kind' = 'sequence',
    'fields.id.start' = '1',
    'fields.id.end' = '1000'
);

-- Query the table
SELECT * FROM example_table LIMIT 10;
```

#### Kafka Integration Examples

```sql
-- Create a Kafka source table with Avro format
CREATE TABLE kafka_avro_source (
    user_id BIGINT,
    item_id STRING,
    category_id STRING,
    behavior STRING,
    ts TIMESTAMP(3),
    WATERMARK FOR ts AS ts - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'user_behavior',
    'properties.bootstrap.servers' = 'your-kafka-bootstrap-servers',
    'properties.group.id' = 'flink-consumer-group',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-256',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="your-username" password="your-password";',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'avro'
);

-- Create a Kafka sink table with JSON format
CREATE TABLE kafka_json_sink (
    user_id BIGINT,
    item_count BIGINT,
    last_behavior STRING,
    window_start TIMESTAMP(3),
    window_end TIMESTAMP(3)
) WITH (
    'connector' = 'kafka',
    'topic' = 'user_behavior_aggregated',
    'properties.bootstrap.servers' = 'your-kafka-bootstrap-servers',
    'properties.security.protocol' = 'SASL_SSL',
    'properties.sasl.mechanism' = 'SCRAM-SHA-256',
    'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.scram.ScramLoginModule required username="your-username" password="your-password";',
    'format' = 'json'
);

-- Stream processing with windowed aggregation
INSERT INTO kafka_json_sink
SELECT
    user_id,
    COUNT(*) as item_count,
    FIRST_VALUE(behavior) as last_behavior,
    TUMBLE_START(ts, INTERVAL '1' MINUTE) as window_start,
    TUMBLE_END(ts, INTERVAL '1' MINUTE) as window_end
FROM kafka_avro_source
GROUP BY user_id, TUMBLE(ts, INTERVAL '1' MINUTE);
```

#### Working with Avro Schemas

```sql
-- Create table using Avro schema registry
CREATE TABLE orders_avro (
    order_id STRING,
    customer_id STRING,
    order_amount DECIMAL(10,2),
    order_timestamp TIMESTAMP(3),
    WATERMARK FOR order_timestamp AS order_timestamp - INTERVAL '30' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'orders',
    'properties.bootstrap.servers' = 'localhost:9092',
    'format' = 'avro',
    'avro.schema' = '{
        "type": "record",
        "name": "Order",
        "fields": [
            {"name": "order_id", "type": "string"},
            {"name": "customer_id", "type": "string"},
            {"name": "order_amount", "type": {"type": "bytes", "logicalType": "decimal", "precision": 10, "scale": 2}},
            {"name": "order_timestamp", "type": {"type": "long", "logicalType": "timestamp-millis"}}
        ]
    }'
);
```

**Check current cluster state using the scaling script:**

```bash
# Get comprehensive cluster status
./scale.sh --status

# Alternative: Check manually
kubectl get flinkdeployment flink-session-cluster -n flink-studio
kubectl get pods -n flink-studio -l component=taskmanager
kubectl get resourcequota flink-studio-quota -n flink-studio
```

**Monitor scaling progress:**

```bash
# Watch TaskManager pods during scaling
kubectl get pods -n flink-studio -l component=taskmanager -w

# Monitor cluster resource usage
kubectl top pods -n flink-studio
```

### 🔧 Configuration

Default settings in `scale.sh`:

- **Namespace**: `flink-studio`
- **TaskManager Memory**: 8Gi per replica
- **TaskManager CPU**: 2 cores per replica  
- **Slots per TaskManager**: 2
- **Environments**: GCP and AKS
- **Resource Quota**: 48Gi memory, 16 CPU (adjustable in manifests/05-resource-quotas.yaml)

### 🚨 Troubleshooting Scaling

**Common issues and solutions:**

| Issue                       | Solution                                                                                     |
| --------------------------- | -------------------------------------------------------------------------------------------- |
| Permission denied           | `chmod +x scale.sh`                                                                     |
| Wrong Kubernetes context    | Script will show current context and ask for confirmation before proceeding |
| Context confirmation denied | Use `kubectl config use-context <name>` to switch to the correct cluster |
| Resource quota exceeded     | Update `manifests/05-resource-quotas.yaml` or reduce replica count |
| Manifest file not found     | Ensure you're running from the deployment directory                                                |
| Scaling validation failed   | Run `./scale.sh --status` to check current state                                           |
| Insufficient cluster resources | Check node capacity with `kubectl describe nodes`                                           |

**Detailed troubleshooting steps:**

```bash
# 1. Check cluster status and resource usage
./scale.sh --status

# 2. Verify cluster health before scaling
kubectl get flinkdeployment flink-session-cluster -n flink-studio
kubectl get pods -n flink-studio

# 3. Check resource quotas and limits
kubectl get resourcequota flink-studio-quota -n flink-studio
kubectl describe resourcequota flink-studio-quota -n flink-studio

# 4. Examine TaskManager logs if scaling fails
kubectl logs -n flink-studio -l component=taskmanager --tail=50

# 5. Check node resources
kubectl describe nodes
kubectl get events -n flink-studio --sort-by='.lastTimestamp'

# 6. Use dry-run to validate changes
./scale.sh --dry-run <target-replicas>
```

**Access Flink UI for manual job management:**

```bash
kubectl port-forward -n flink-studio service/flink-session-cluster 8081:8081
# Then open: http://localhost:8081
```

### 📊 Best Practices

1. **Use the Scaling Script**: Always use `./scale.sh` for safe, validated scaling operations
2. **Check Status First**: Run `./scale.sh --status` before making changes
3. **Verify Context**: The script will show your current context and ask for confirmation
4. **Use Dry-Run**: Preview changes with `./scale.sh --dry-run <replicas>` 
5. **Monitor Resources**: Keep cluster utilization < 80% for optimal performance
6. **Scale Gradually**: For large changes, consider incremental scaling (4→6→8 vs 4→8)
7. **Double-Check Context**: Always confirm you're targeting the correct cluster when prompted
8. **Test in Development**: Validate scaling behavior with your specific workloads
9. **Resource Planning**: Each TaskManager uses 8Gi memory + 2 CPU cores

### 🔄 How Job Rebalancing Works

The enhanced scaling script leverages Flink's native capabilities:

- **Automatic Redistribution**: Flink automatically redistributes tasks across available slots
- **No Downtime**: Jobs continue processing during the entire scaling operation
- **State Preservation**: All job state is preserved during rebalancing
- **Backpressure Handling**: Flink manages backpressure during resource changes
- **Slot Allocation**: The script sets minimum slots to ensure proper resource allocation

**Example of seamless rebalancing:**

```bash
# Before scaling: 4 TaskManagers, 16 slots, 12 slots used
./safe-scale.sh 6
# After scaling: 6 TaskManagers, 24 slots, same jobs running with better distribution
```

For advanced scaling scenarios and performance tuning, see the [Flink Documentation](https://nightlies.apache.org/flink/flink-docs-stable/docs/deployment/resource-providers/native_kubernetes/#manual-resource-management).

## Monitoring and Troubleshooting

### Deployment Testing and Validation

Use the comprehensive test script to validate deployment health:

```bash
# Run full test suite
./test-deployment.sh

# View test script help
./test-deployment.sh --help
```

The test script provides detailed validation of:

- Kubernetes prerequisites and cluster connectivity
- Flink deployment status and pod health
- Init container execution and library downloads
- Required connector libraries in all pods
- Flink UI accessibility and cluster topology
- TaskManager registration and connectivity
- Avro and Kafka connector functionality

### Check Component Status

```bash
# Check all pods
kubectl get pods -n flink-studio

# Check Flink cluster status
kubectl get flinkdeployment -n flink-studio

# Detailed pod information
kubectl describe pod <pod-name> -n flink-studio

# Check init container logs for library downloads
kubectl logs <pod-name> -n flink-studio -c flink-plugin-setup

# Check main container logs
kubectl logs deployment/flink-sql-gateway -n flink-studio
kubectl logs deployment/hue -n flink-studio
```

### Common Issues

#### 1. Flink Cluster Not Starting

**Symptoms**: Pods stuck in `Pending` or `Init:0/1` state

**Solutions**:

- Check resource availability: `kubectl describe nodes`
- Verify cloud storage access permissions
- Check operator logs: `kubectl logs -n flink-system deployment/flink-kubernetes-operator`
- For GCP: Verify Workload Identity setup and GCS bucket permissions
- For Azure: Ensure storage account key secret exists and is correct
- Check init container logs: `kubectl logs <pod> -c flink-plugin-setup -n flink-studio`

#### 2. Library Download Failures

**Symptoms**: Init containers failing with download errors

**Solutions**:

- Verify internet connectivity from cluster nodes
- Check Maven Central accessibility: `kubectl exec <pod> -- curl -I https://repo1.maven.org/maven2/`
- Review init container logs for specific download failures
- Ensure proper proxy configuration if behind corporate firewall

#### 3. Missing Libraries in Runtime

**Symptoms**: Avro/Kafka connectors not available in Flink jobs

**Solutions**:

- Run library validation: `./test-deployment.sh --libs-only`
- Check shared volume contents: `kubectl exec <pod> -- ls -la /opt/flink/lib-extra/`
- Manually copy libraries if needed: `kubectl exec <pod> -- cp /opt/flink/lib-extra/*.jar /opt/flink/lib/`
- Restart deployment if libraries were added post-startup

#### 4. SQL Gateway Connection Issues

**Symptoms**: Hue cannot connect to SQL Gateway, queries fail

**Solutions**:

- Verify Flink cluster is ready: `kubectl get flinkdeployment -n flink-studio`
- Check service endpoints: `kubectl get endpoints -n flink-studio`
- Test gateway directly: `curl http://localhost:8083/v1/info` (via port-forward)
- Validate network policies allow traffic between components

#### 5. Kafka Connectivity Issues

**Symptoms**: Kafka table creation fails, authentication errors

**Solutions**:

- Verify Kafka bootstrap servers configuration
- Check authentication credentials (OAuth tokens, certificates)
- Test connectivity from Flink pods: `kubectl exec <pod> -- telnet <kafka-server> 9092`
- Validate security protocols and SASL mechanisms

#### 6. Avro Schema Issues

**Symptoms**: Avro deserialization failures, schema compatibility errors

**Solutions**:

- Validate Avro schema format and syntax
- Check schema registry connectivity if using external registry
- Verify schema evolution compatibility
- Test with simple Avro schemas first
- Enable Avro debugging: Add `'avro.decode-error-policy' = 'fail'` to table options

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

| Issue                              | Solution                                                                  |
| ---------------------------------- | ------------------------------------------------------------------------- |
| Insufficient resources             | Check cluster capacity with `kubectl describe nodes`                      |
| Cloud storage access issues        | Verify GCS bucket/Azure storage account permissions                       |
| Image pull failures                | Check internet connectivity and image availability                        |
| Workload Identity issues (GCP)     | Verify service account binding and permissions                            |
| Storage account key issues (Azure) | Check secret creation and validity                                        |
| Library download failures          | Run `./test-deployment.sh --libs-only` to diagnose                        |
| Init container errors              | Check init container logs with `kubectl logs <pod> -c flink-plugin-setup` |

### Runtime Issues

| Issue                  | Solution                                            |
| ---------------------- | --------------------------------------------------- |
| Jobs fail to start     | Check Flink logs and resource allocation            |
| SQL queries timeout    | Increase gateway timeout settings                   |
| Hue login issues       | Verify Hue database and configuration               |
| Kafka connector issues | Validate connectivity and authentication settings   |
| Avro format errors     | Check schema compatibility and format configuration |
| Missing connectors     | Run comprehensive test: `./test-deployment.sh`      |

### Using the Test Script for Diagnostics

The comprehensive test script provides detailed diagnostics:

```bash
# Full deployment validation
./test-deployment.sh

# Focus on specific issues
./test-deployment.sh --libs-only      # Library validation only
./test-deployment.sh --pods-only      # Pod status only
./test-deployment.sh --connectivity   # Network connectivity only
./test-deployment.sh --monitor        # Continuous monitoring mode

# Debug mode with verbose output
./test-deployment.sh --debug
```

## Contributing

When making changes to the platform:

1. **Test changes thoroughly**: Use `./test-deployment.sh` to validate all components
2. **Update documentation**: Keep README.md and related docs current with changes
3. **Validate library compatibility**: Test new connector versions with existing workloads
4. **Check resource requirements**: Ensure cluster has sufficient resources for changes
5. **Update version numbers**: Keep manifest versions consistent across environments
6. **Test connector functionality**: Validate Kafka and Avro connectors work as expected

### Adding New Connectors

To add additional Flink connectors:

1. **Identify Maven coordinates**: Find the connector artifact in Maven Central
2. **Update init container**: Add download command to `03-flink-session-cluster-gcp.yaml`
3. **Test integration**: Run `./test-deployment.sh --libs-only` to verify library loading
4. **Update documentation**: Add connector details to README.md and example queries
5. **Validate functionality**: Create test SQL statements to verify connector works

## Support

For issues and questions:

1. **Use the test script first**: Run `./test-deployment.sh` for comprehensive diagnostics
2. **Check troubleshooting guide**: Review the expanded troubleshooting section above
3. **Review component logs**:
   - Flink logs: `kubectl logs <flink-pod> -n flink-studio`
   - Init container logs: `kubectl logs <pod> -c flink-plugin-setup -n flink-studio`
   - Operator logs: `kubectl logs -n flink-system deployment/flink-kubernetes-operator`
4. **Validate connector availability**: Use `./test-deployment.sh --libs-only`
5. **Check Kubernetes events**: `kubectl get events -n flink-studio --sort-by='.lastTimestamp'`
6. **Review official documentation**:
   - [Apache Flink Documentation](https://flink.apache.org/docs/)
   - [Flink Kubernetes Operator](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-stable/)
   - [Flink SQL Connectors](https://nightlies.apache.org/flink/flink-docs-stable/docs/connectors/table/)

### Quick Health Check

```bash
# Comprehensive health check
./test-deployment.sh

# Quick status overview
kubectl get pods,svc,flinkdeployment -n flink-studio
```
