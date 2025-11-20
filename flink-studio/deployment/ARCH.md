# Flink SQL Studio on Kubernetes: Architecture & Implementation

This document outlines the architecture and implementation of a production-ready Flink SQL Studio on Kubernetes with multi-cloud support. The platform provides a seamless environment for executing Flink SQL queries with enterprise-grade security and scalability.

---

## 1. Solution Architecture

The platform consists of four core components deployed across GCP (GKE) and Azure (AKS) environments.

```
+---------------------+
|                     |
|  Custom SQL         |
|  Executor (CLI)     |
|  + Environment      |
|    Configuration    |
+---------------------+
           |
           | REST API
           v
+---------------------------------------------------------------------------------+
|                                                                                 |
|                     Kubernetes Cluster (flink-studio namespace)                |
|                                                                                 |
|   +-------------------------+     +-------------------------------------+       |
|   |                         |     |                                     |       |
|   |   Flink SQL Gateway     |---->|    Flink Session Cluster (HA)      |       |
|   |    (REST API)           |     |                                     |       |
|   |                         |     |  +---------------+ +-------------+  |       |
|   +-------------------------+     |  | JobManager(HA)| | TaskManagers|  |       |
|                                   |  +---------------+ +-------------+  |       |
|                                   |        |                |           |       |
|                                   |        v                v           |       |
|                                   |  +---------------------------+      |       |
|                                   |  | Cloud Storage (GCS/Azure) |      |       |
|                                   |  | - Checkpoints             |      |       |
|                                   |  | - Savepoints              |      |       |
|                                   |  | - HA Metadata             |      |       |
|                                   |  +---------------------------+      |       |
|                                   |                                     |       |
|                                   +-------------------------------------+       |
|                                   (Managed by Flink Kubernetes Operator)       |
|                                                                                 |
+---------------------------------------------------------------------------------+
           |
           v
+---------------------------------------------------------------------------------+
|                              External Services                                  |
|                                                                                 |
|   +----------------------+              +---------------------------+           |
|   |  Aiven Kafka         |              |  Cloud Authentication     |           |
|   |  - SASL/SSL Auth     |              |  - GCP: Workload Identity |           |
|   |  - Avro/JSON Format  |              |  - Azure: Workload Identity|          |
|   +----------------------+              +---------------------------+           |
|                                                                                 |
+---------------------------------------------------------------------------------+
```

### Core Components:

1.  **Flink Kubernetes Operator (v1.12.1)**: Automates the deployment, scaling, and lifecycle management of Flink clusters on Kubernetes using custom resources (FlinkDeployment).

2.  **Flink Session Cluster (v2.0.0)**: A long-running, highly available Flink cluster with:
    - RocksDB state backend with cloud storage for checkpoints/savepoints
    - Kubernetes-native HA with cloud storage backend
    - Pre-configured Kafka (Aiven) and Avro connectors
    - Workload Identity authentication (no stored credentials)
    - Optimized for medium-sized stateful jobs (8GB TaskManagers)

3.  **Flink SQL Gateway**: REST API service for SQL query submission and management, configured to communicate with the session cluster JobManager.

4.  **Custom SQL Executor (Python CLI)**: Production-grade command-line tool that:
    - Loads environment-specific configuration from `.env` files
    - Supports variable substitution in SQL (e.g., `${KAFKA_ENV}`, `${KAFKA_USERNAME}`)
    - Executes single or batch SQL statements
    - Provides comprehensive error handling and logging
    - Integrates with Aiven Kafka via encrypted credentials

---

## 2. Multi-Cloud Deployment Architecture

The platform supports both **Google Cloud Platform (GKE)** and **Microsoft Azure (AKS)** with cloud-specific optimizations.

### **Cloud Provider Differences**

| Feature | GCP (GKE) | Azure (AKS) |
|---------|-----------|-------------|
| **Flink Image** | Custom image from Artifact Registry:<br/>`asia-docker.pkg.dev/sbx-ci-cd/public/flink:2.0.0` | Custom image from Artifact Registry:<br/>`asia-docker.pkg.dev/sbx-ci-cd/public/flink:2.0.0` |
| **Authentication** | GCP Workload Identity | Azure Workload Identity |
| **Storage** | Google Cloud Storage (GCS):<br/>`gs://sbx-stag-flink-storage/` | Azure Blob Storage with Data Lake Gen2:<br/>`abfss://flink@sbxunileverflinkstorage1.dfs.core.windows.net/` |
| **Service Account** | `flink-gcs@sbx-stag.iam.gserviceaccount.com` | Managed Identity: `flink-identity`<br/>Client ID: `911d60a1-3770-40cb-978b-8b7342bf02b8` |
| **TaskManager Storage** | None (uses cloud storage directly) | 50GB persistent volume per TaskManager for RocksDB |
| **Node Affinity** | Standard nodes | Spot instances (cost optimization) |

### **Security Model: Workload Identity**

Both cloud deployments use **Workload Identity** for passwordless authentication:

#### GCP Workload Identity
```yaml
serviceAccount: flink
annotations:
  iam.gke.io/gcp-service-account: flink-gcs@sbx-stag.iam.gserviceaccount.com
```
- **No service account keys** stored in the cluster
- Automatic credential rotation by GCP
- IAM-based access control to GCS buckets

#### Azure Workload Identity
```yaml
serviceAccount: flink
annotations:
  azure.workload.identity/client-id: 911d60a1-3770-40cb-978b-8b7342bf02b8
labels:
  azure.workload.identity/use: "true"
```
- **No storage account keys** stored in the cluster
- Federated identity credentials for seamless auth
- Azure RBAC-based access control

---

## 3. Deployment Steps

The deployment is fully automated via `./scripts/deploy.sh` and follows this sequence:

### **Step 1: Install Flink Kubernetes Operator**

Installs the official Flink Kubernetes Operator (v1.12.1) into the `flink-system` namespace using Helm.

### **Step 2: Create Platform Infrastructure**

Creates:
- `flink-studio` namespace
- Cloud-specific RBAC (ServiceAccount with Workload Identity annotations)
- Resource quotas for cost control

### **Step 3: Configure Cloud Authentication**

**For GCP:**
- Creates Google Service Account: `flink-gcs@sbx-stag.iam.gserviceaccount.com`
- Grants Storage Admin role to GCS bucket
- Binds Kubernetes ServiceAccount to Google Service Account via Workload Identity

**For Azure:**
- Verifies Managed Identity `flink-identity` exists
- Creates federated identity credential linking K8s ServiceAccount
- Verifies storage container access

### **Step 4: Deploy Aiven Kafka Credentials**

Deploys the `aiven-credentials` Kubernetes secret containing:
- Kafka username/password
- JKS truststore for SSL/TLS
- Truststore password

This secret is mounted into Flink pods for secure Kafka connectivity.

### **Step 5: Deploy Flink Session Cluster**

Deploys the `FlinkDeployment` custom resource with:
- Cloud-specific storage configuration
- RocksDB state backend optimized for persistent storage
- Kubernetes-native HA with cloud storage backend
- Pre-configured Kafka and Avro connectors
- Environment-specific configuration (via templates for Azure)

### **Step 6: Deploy Flink SQL Gateway**

Deploys the SQL Gateway as a Kubernetes Deployment with ClusterIP service on port 8083.

### **Step 7: Apply Network Policies**

Applies Kubernetes NetworkPolicies to restrict traffic between components for security.

---

## 4. Environment Configuration (Azure-Specific)

Azure deployments use **environment-specific configuration files** (`.env` files) with template-based manifest generation:

### **Environment Files**
```
flink-studio/deployment/
├── .samadhan-prod.env
├── .sbx-uat.env
└── manifests/
    └── 03-flink-session-cluster-aks.yaml.template
```

### **Template Variables**
- `${AZURE_STORAGE_ACCOUNT_NAME}` - Azure storage account name
- `${AZURE_STORAGE_CONTAINER_NAME}` - Storage container name
- `${AZURE_TENANT_ID}` - Azure AD tenant ID
- `${AZURE_CLIENT_ID}` - Managed identity client ID
- `${K8S_NAMESPACE}` - Kubernetes namespace
- `${K8S_SERVICE_ACCOUNT}` - Kubernetes service account name

The `deploy.sh` script prompts for environment selection and generates the final manifest using `envsubst`.

---

## 5. Production Features

### **High Availability**
- Kubernetes-native HA for JobManager with cloud storage backend
- Automatic failover and recovery
- Retained checkpoints on job cancellation

### **State Management**
- RocksDB state backend with incremental checkpointing
- Checkpoints stored in cloud storage (GCS/Azure Blob)
- Savepoints for manual job migration
- Optimized for medium-sized jobs (8GB memory, 50GB storage on Azure)

### **Security**
- Workload Identity (no stored credentials)
- Kubernetes NetworkPolicies for traffic isolation
- Resource quotas for cost control
- Encrypted Kafka communication via SSL/TLS
- Kubernetes secrets for sensitive credentials

### **Observability**
- Job history archived to cloud storage
- 50 historical jobs retained in Web UI
- 100 checkpoint history entries
- Comprehensive logging to stdout/stderr
