# Kafka Setup and Management

This directory contains all Kafka-related configurations, connectors, and management scripts for Debezium CDC (Change Data Capture) and topic management in Kubernetes environments.

## Prerequisites

- `kubectl` configured with appropriate context
- Access to Kubernetes namespace with Kafka Connect pods
- Environment configuration files (`.env`) for each environment

## Environment Configuration

All scripts require an environment configuration file specified with `--env` parameter.

Example environment files:
- `.sbx-uat.env` - Sandbox UAT environment
- `.prod.env` - Production environment

Required environment variables:
```bash
K8S_NAMESPACE           # Kubernetes namespace
K8S_CONNECT_LABEL       # Label selector for Connect pods
KAFKA_BOOTSTRAP_SERVERS # Kafka bootstrap servers
KAFKA_REST_URL          # Kafka REST API URL
SCHEMA_REGISTRY_URL     # Schema Registry URL
K8S_AIVEN_SECRET        # Kubernetes secret with Aiven credentials
CONNECT_LOCAL_PORT      # Local port for port forwarding
CONNECT_REMOTE_PORT     # Remote Connect port
CONNECT_API_URL         # Connect REST API URL
```

## Common Library

`scripts/common.sh` - Shared functions and utilities used by all scripts:
- Environment file loading and validation
- Kubernetes context checking
- Credential fetching from secrets
- Kafka command execution via pods
- Port forwarding management
- Output formatting and logging

## Directory Structure

```
kafka-setup/
├── manifests/              # Kubernetes manifest files
│   └── sbx-uat/           # Environment-specific manifests
│       ├── kafka-connect.yaml
│       └── kafka-setup.yaml
├── scripts/                # All management and deployment scripts
│   ├── backbone-debezium-postgres.sh
│   ├── encarta-debezium-postgres.sh
│   ├── wms-debezium-postgres.sh
│   ├── common.sh          # Shared utilities
│   ├── create-signal-topics.sh
│   ├── deploy-all-connectors.sh
│   ├── deploy-manifests.sh
│   ├── manage-schemas.sh
│   ├── manage-topics.sh
│   ├── trigger-snapshots.sh
│   └── *.sql              # Publication SQL files
└── README.md
```

## Scripts

### Kubernetes Manifest Deployment

#### `scripts/deploy-manifests.sh`
Deploy Kubernetes manifests for Kafka setup.

```bash
# Deploy manifests for an environment
./scripts/deploy-manifests.sh --env sbx-uat

# Dry run to validate manifests
./scripts/deploy-manifests.sh --env sbx-uat --dry-run

# Deploy with namespace override
./scripts/deploy-manifests.sh --env sbx-uat --namespace custom-kafka
```

Features:
- Environment-based manifest deployment
- Dry-run validation
- Namespace override option
- Deployment status summary

### Connector Deployment

#### `scripts/deploy-all-connectors.sh`
Deploy all Debezium connectors at once.

```bash
# Deploy all connectors
./scripts/deploy-all-connectors.sh --env .sbx-uat.env

# Dry run mode
./scripts/deploy-all-connectors.sh --env .sbx-uat.env --dry-run

# Skip specific connectors
./scripts/deploy-all-connectors.sh --env .sbx-uat.env --skip encarta

# Skip multiple connectors
./scripts/deploy-all-connectors.sh --env .sbx-uat.env --skip backbone --skip wms
```

Features:
- Deploy all connectors in sequence
- Skip specific connectors as needed
- Dry-run mode for validation
- Summary report of deployment status

### Topic Management

#### `scripts/manage-topics.sh`
Unified script for all topic operations (list, create, update, delete).

```bash
# List all topics
./scripts/manage-topics.sh --env .sbx-uat.env list

# List topics with details
./scripts/manage-topics.sh --env .sbx-uat.env list --details

# List topics matching pattern
./scripts/manage-topics.sh --env .sbx-uat.env list --filter "^sbx_uat.wms.*"

# Create a topic
./scripts/manage-topics.sh --env .sbx-uat.env create --topic test-topic --partitions 3

# Create topic with configs
./scripts/manage-topics.sh --env .sbx-uat.env create --topic important-topic \
  --config retention.ms=-1 --config compression.type=lz4

# Update topic to infinite retention
./scripts/manage-topics.sh --env .sbx-uat.env update --filter "^test-topic$" --cleanup-policy infinite

# Update specific configs
./scripts/manage-topics.sh --env .sbx-uat.env update --filter "^test-.*" --config compression.type=snappy

# Delete topics matching pattern
./scripts/manage-topics.sh --env .sbx-uat.env delete --filter "^test-.*"

# Delete with dry-run
./scripts/manage-topics.sh --env .sbx-uat.env delete --filter "^temp-.*" --dry-run
```

Features:
- **list**: View topics with optional filtering and details
- **create**: Create new topics with custom configurations
- **update**: Modify topic configurations in bulk
- **delete**: Remove topics with pattern matching and safety checks
- **--dry-run**: Preview changes without applying them
- **Protection**: Signal topics and internal Kafka topics are protected from deletion

### Individual Debezium Connectors

#### `scripts/wms-debezium-postgres.sh`
Deploy WMS Postgres Debezium connector.

```bash
./scripts/wms-debezium-postgres.sh --env .sbx-uat.env
```

#### `scripts/encarta-debezium-postgres.sh`
Deploy Encarta Postgres Debezium connector.

```bash
./scripts/encarta-debezium-postgres.sh --env .sbx-uat.env
```

#### `scripts/backbone-debezium-postgres.sh`
Deploy Backbone Postgres Debezium connector.

```bash
./scripts/backbone-debezium-postgres.sh --env .sbx-uat.env
```

### Signal Topics

#### `scripts/create-signal-topics.sh`
Create Debezium signal topics for incremental snapshots.

```bash
./scripts/create-signal-topics.sh --env .sbx-uat.env
```

Creates signal topics for:
- WMS connector
- Encarta connector
- Backbone connector

### Incremental Snapshots

#### `scripts/trigger-snapshots.sh`
Trigger incremental snapshots for specific tables.

```bash
# Trigger snapshot for specific table
./scripts/trigger-snapshots.sh --env .sbx-uat.env --connector wms --table public.inventory

# Trigger snapshots for multiple tables
./scripts/trigger-snapshots.sh --env .sbx-uat.env --connector wms \
  --tables "public.inventory,public.task,public.order"

# Use from file
./scripts/trigger-snapshots.sh --env .sbx-uat.env --connector wms --from-file tables.txt
```

Features:
- Single or multiple table snapshots
- Custom ORDER BY clauses for specific tables
- Batch processing from file
- Automatic signal topic validation

### Schema Management

#### `scripts/manage-schemas.sh`
Manage schemas in Schema Registry (list and delete).

```bash
# List all schemas
./scripts/manage-schemas.sh --env .sbx-uat.env list

# List schemas matching pattern
./scripts/manage-schemas.sh --env .sbx-uat.env list --filter "wms.*"

# Delete schemas matching pattern
./scripts/manage-schemas.sh --env .sbx-uat.env delete --filter "^test-.*"

# Dry run mode
./scripts/manage-schemas.sh --env .sbx-uat.env delete --filter "^temp-.*" --dry-run

# Force deletion without confirmation
./scripts/manage-schemas.sh --env .sbx-uat.env delete --filter "^old-.*" --force
```

Features:
- **list**: View all schemas with optional filtering
- **delete**: Remove schemas with pattern matching
- **Protection**: Signal topic schemas are protected from deletion
- **Safety**: Multiple confirmation prompts for deletions

## SQL Files

- `scripts/wms-publications.sql` - WMS database publication configuration
- `scripts/encarta-publications.sql` - Encarta database publication configuration
- `scripts/backbone-publications.sql` - Backbone database publication configuration

These SQL files contain the publication definitions for logical replication used by Debezium connectors.

## Safety Features

All scripts include:
- Kubernetes context confirmation
- Environment validation
- Dry-run mode for preview
- Protection for critical topics (signal topics, internal Kafka topics)
- Confirmation prompts for destructive operations
- Detailed logging with color-coded output

## Best Practices

1. Always verify the Kubernetes context before running scripts
2. Use `--dry-run` to preview changes before applying
3. Keep environment files secure (they're gitignored)
4. Test changes in non-production environments first
5. Use pattern filters carefully to avoid unintended matches
6. Review the list of affected resources before confirming deletions

## Troubleshooting

Enable debug output:
```bash
DEBUG=true ./scripts/manage-topics.sh --env .sbx-uat.env list
```

Check pod logs:
```bash
kubectl logs -n <namespace> <pod-name>
```

Verify connectivity:
```bash
kubectl exec -n <namespace> <pod-name> -- curl -s $KAFKA_REST_URL/topics
```