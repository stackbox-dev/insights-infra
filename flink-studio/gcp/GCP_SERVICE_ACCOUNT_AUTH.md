# GCP Service Account Authentication Setup and Verification Guide

This guide explains how to ensure your Flink deployment properly uses Google Cloud Platform (GCP) Service Account JSON keys for secure access to Google Cloud Storage (GCS).

## What is Service Account Authentication?

Service Account authentication allows your Kubernetes workloads to securely access Google Cloud services using a service account JSON key file. The key is stored as a Kubernetes secret and mounted into your pods.

## Current Configuration

The Docker image and Kubernetes manifests are configured to use Service Account JSON keys with the following setup:

### Docker Image Components

1. **GCS Connector**: `gcs-connector-hadoop3-2.2.21.jar` for Hadoop/Flink GCS integration
2. **Google Cloud Libraries**: Additional client libraries for authentication support
3. **Hadoop Configuration**: `core-site.xml` configured for service account key authentication
4. **Verification Script**: `/opt/flink/bin/verify-gcp-auth.sh` for testing

### Kubernetes Configuration

1. **Service Account**: `flink` service account for Kubernetes RBAC
2. **Secret**: `gcp-service-account-key` containing the service account JSON key
3. **Volume Mounts**: Service account key mounted at `/opt/flink/conf/service-account.json`
4. **Environment Variables**: `GOOGLE_APPLICATION_CREDENTIALS` pointing to the key file

## Prerequisites

Before deploying, ensure you have:

1. **GCS Bucket**: `gs://sbx-stag-flink-storage/` created and accessible
2. **gcloud CLI**: Installed and authenticated with appropriate permissions
3. **kubectl**: Configured to access your GKE cluster

## Automated Setup

The `deploy.sh` script will automatically:

1. Create Google Service Account `flink-gcs@sbx-stag.iam.gserviceaccount.com`
2. Grant Storage Admin permissions on the GCS bucket
3. Generate and download the service account JSON key
4. Create Kubernetes secret with the key file
5. Verify the secret is created correctly

Simply run:

```bash
./deploy.sh
```

## Manual Setup Commands (if needed)

If you need to set up manually:

```bash
# 1. Create Google Service Account
gcloud iam service-accounts create flink-gcs \
    --display-name="Flink GCS Service Account" \
    --project=sbx-stag

# 2. Grant Storage permissions
gsutil iam ch serviceAccount:flink-gcs@sbx-stag.iam.gserviceaccount.com:roles/storage.admin \
  gs://sbx-stag-flink-storage/

# 3. Generate service account key
gcloud iam service-accounts keys create gcp-service-account-key.json \
    --iam-account=flink-gcs@sbx-stag.iam.gserviceaccount.com \
    --project=sbx-stag

# 4. Create Kubernetes secret
kubectl create secret generic gcp-service-account-key \
    --from-file=service-account.json=gcp-service-account-key.json \
    -n flink-studio
```

## Verification

### 1. Build and Deploy

```bash
# Build the Docker image
cd gcp
./build-image.sh

# Deploy to Kubernetes (includes service account setup)
cd ..
./deploy.sh
```

### 2. Test Service Account Authentication

Once deployed, run the verification script inside a Flink pod:

```bash
# Get into a Flink pod
kubectl exec -it deployment/flink-session-cluster -n flink-studio -- bash

# Run the verification script
/opt/flink/bin/verify-gcp-auth.sh
```

### 3. Manual Verification

You can also manually verify the setup:

```bash
# Check if service account key is mounted
kubectl exec -it deployment/flink-session-cluster -n flink-studio -- \
  ls -la /opt/flink/conf/service-account.json

# Test GCS access
kubectl exec -it deployment/flink-session-cluster -n flink-studio -- \
  gsutil ls gs://sbx-stag-flink-storage/

# Check environment variable
kubectl exec -it deployment/flink-session-cluster -n flink-studio -- \
  echo $GOOGLE_APPLICATION_CREDENTIALS
```

## Troubleshooting

### Common Issues

1. **Service account key not found**
   - Check if Kubernetes secret exists: `kubectl get secret gcp-service-account-key -n flink-studio`
   - Verify volume mount in pod specification
   - Check if secret contains valid JSON: `kubectl get secret gcp-service-account-key -n flink-studio -o jsonpath='{.data.service-account\.json}' | base64 -d | jq .`

2. **Permission denied on GCS**
   - Verify Google Service Account has Storage Admin role
   - Check if service account key is valid and not expired
   - Ensure the service account has access to the specific bucket

3. **Authentication errors**
   - Verify `GOOGLE_APPLICATION_CREDENTIALS` environment variable is set correctly
   - Check if service account key file is readable
   - Ensure Hadoop configuration points to the correct key file path

### Debug Commands

```bash
# Check Kubernetes secret
kubectl get secret gcp-service-account-key -n flink-studio -o yaml

# Verify service account key content
kubectl get secret gcp-service-account-key -n flink-studio -o jsonpath='{.data.service-account\.json}' | base64 -d | jq .

# Check Google Service Account
gcloud iam service-accounts describe flink-gcs@sbx-stag.iam.gserviceaccount.com

# Test authentication from pod
kubectl exec -it deployment/flink-session-cluster -n flink-studio -- \
  gcloud auth activate-service-account --key-file=/opt/flink/conf/service-account.json
```

## Security Considerations

1. **Key Rotation**: Periodically rotate service account keys for better security
2. **Least Privilege**: Grant only necessary permissions (Storage Admin for the specific bucket)
3. **Secure Storage**: The JSON key is stored as a Kubernetes secret with base64 encoding
4. **Access Control**: Use Kubernetes RBAC to control who can access the secret
5. **Monitoring**: Monitor service account usage in Cloud Console

## Configuration Files

- `Dockerfile`: Contains all necessary dependencies and configurations
- `core-site.xml`: Hadoop configuration for GCS access with service account key
- `02-rbac-gcp.yaml`: Kubernetes RBAC configuration
- `03-flink-session-cluster-gcp.yaml`: Flink deployment with service account key mount
- `04-flink-sql-gateway.yaml`: SQL Gateway with service account key mount
- `verify-gcp-auth.sh`: Verification script for testing the authentication setup
- `deploy.sh`: Automated deployment script that sets up everything

The configuration provides a straightforward and reliable way to authenticate with GCP services using service account keys, with comprehensive tooling for setup, verification, and troubleshooting.
