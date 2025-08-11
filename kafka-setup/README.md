# Kafka Setup

This repository contains scripts and manifests for setting up and managing Kafka clusters, connectors, and related infrastructure.

## Directory Structure

```
kafka-setup/
├── connectors/           # Scripts for managing Kafka connectors
│   ├── .sample.env      # Template environment configuration
│   ├── .sbx-uat.env     # Example: sbx-uat environment config
│   ├── common.sh        # Shared library functions
│   └── *.sh             # Connector management scripts
└── manifests/           # Kubernetes manifests
    └── sbx-uat/         # Example: sbx-uat environment
        ├── kafka-connect.yaml
        └── kafka-setup.yaml
```

## Environment Configuration

All scripts use environment files (`.env`) to manage configuration across different environments. This allows the same scripts to work with staging, production, or any other environment.

### Setting Up a New Environment

1. **Copy the sample environment file:**
   ```bash
   cd connectors
   cp .sample.env .your-env.env
   ```

2. **Update the configuration values** in `.your-env.env` with your environment-specific settings:
   - Kafka endpoints
   - Kubernetes namespace and labels
   - Database connections
   - Connector names and prefixes

3. **Create Kubernetes secrets** for your environment:

   **Aiven/Kafka credentials:**
   ```bash
   kubectl create secret generic aiven-credentials \
     --from-literal=username=<username> \
     --from-literal=password=<password> \
     --from-literal=userinfo="<username>:<password>" \
     -n kafka
   ```

   **Database passwords (one per database):**
   ```bash
   kubectl create secret generic <db-password-secret-name> \
     --from-literal=password=<db-password> \
     -n kafka
   ```

## Usage

All scripts require an `--env` parameter pointing to your environment configuration file.

### Managing Connectors

**Deploy/Update a connector:**
```bash
./wms_debezium_postgres.sh --env .your-env.env
./encarta_debezium_postgres.sh --env .your-env.env
./backbone_debezium_postgres.sh --env .your-env.env
```

**Connector Operations via Kafka Connect REST API:**

After port-forwarding to the Connect pod (automatically done by scripts):

```bash
# Pause a connector
curl -X PUT http://localhost:8083/connectors/<connector-name>/pause

# Resume a connector
curl -X PUT http://localhost:8083/connectors/<connector-name>/resume

# Restart a connector
curl -X POST http://localhost:8083/connectors/<connector-name>/restart

# Stop a connector
curl -X PUT http://localhost:8083/connectors/<connector-name>/stop

# Delete connector offsets (resets from beginning - connector must be stopped first)
curl -X DELETE http://localhost:8083/connectors/<connector-name>/offsets

# Delete a connector
curl -X DELETE http://localhost:8083/connectors/<connector-name>

# Get connector status
curl -X GET http://localhost:8083/connectors/<connector-name>/status
```

### Managing Topics

**Create signal topics for incremental snapshots:**
```bash
./create-signal-topics.sh --env .your-env.env
```

**Trigger incremental snapshots:**
```bash
./trigger-snapshots.sh --env .your-env.env -c wms -t "public.inventory,public.task"
```

**Delete topics (with safety features):**
```bash
# Dry run to see what would be deleted
./delete-topics.sh --env .your-env.env --filter "test-.*" --dry-run

# Actually delete topics (requires confirmation)
./delete-topics.sh --env .your-env.env --filter "test-.*"
```

**Update topic configurations:**
```bash
./update-topics.sh --env .your-env.env
```

### Managing Schemas

**Delete schemas from Schema Registry:**
```bash
# Dry run
./delete-schema.sh --env .your-env.env --filter "test-.*" --dry-run

# Actually delete (requires confirmation)
./delete-schema.sh --env .your-env.env --filter "test-.*"
```

## Example: SBX-UAT Environment

The repository includes a complete configuration for the `sbx-uat` environment as an example:

- **Configuration:** `connectors/.sbx-uat.env`
- **Manifests:** `manifests/sbx-uat/`

### SBX-UAT Endpoints

- **Kafka Bootstrap:** `sbx-stag-kafka-stackbox.e.aivencloud.com:22167`
- **Schema Registry:** `https://sbx-stag-kafka-stackbox.e.aivencloud.com:22159`
- **Kafka REST API:** `https://sbx-stag-kafka-stackbox.e.aivencloud.com:22158`

### Using SBX-UAT Environment

```bash
# Create signal topics
./create-signal-topics.sh --env .sbx-uat.env

# Deploy WMS connector
./wms_debezium_postgres.sh --env .sbx-uat.env

# Trigger snapshot for specific tables
./trigger-snapshots.sh --env .sbx-uat.env -c wms -t "public.inventory"

# List topics (dry-run deletion)
./delete-topics.sh --env .sbx-uat.env --dry-run
```

## Safety Features

The deletion scripts (`delete-topics.sh`, `delete-schema.sh`) include multiple safety features:

- **Protected resources:** Signal topics and schemas (debezium-signals-*) cannot be deleted
- **Double confirmation:** Requires typing "yes" and the count of items to delete
- **Dry-run mode:** Preview what would be deleted without actually deleting
- **Kubernetes context check:** Prompts to confirm you're in the right cluster

## Prerequisites

- `kubectl` configured with access to your Kubernetes cluster
- `jq` for JSON processing
- Appropriate Kubernetes secrets created (see Environment Configuration)

## Truststore for Java-based Connectors

If your Kafka cluster uses custom CA certificates:

```bash
# Convert CA to truststore
docker run --rm -v "$PWD":/work openjdk:17-jdk \
  keytool -import \
    -alias kafka-ca \
    -file /work/ca.pem \
    -keystore /work/kafka.truststore.jks \
    -storepass <secret-pass> \
    -noprompt

# Create Kubernetes secret
kubectl create secret generic kafka-truststore-secret \
  --from-file=kafka.truststore.jks=./kafka.truststore.jks \
  --from-literal=truststore-password=<secret-pass> \
  -n kafka
```

## Troubleshooting

1. **Script can't find environment file:**
   - Ensure the file exists and starts with a dot (e.g., `.production.env`)
   - Use the full path if running from a different directory

2. **Kubernetes context issues:**
   - The scripts will show the current context and ask for confirmation
   - Use `kubectl config use-context <context>` to switch contexts

3. **Missing credentials:**
   - Check that Kubernetes secrets are created in the correct namespace
   - Verify secret names match those in your `.env` file

4. **Port forwarding issues:**
   - Ensure no other process is using the port (default: 8083)
   - Check that the Connect pod is running