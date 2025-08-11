# Kafka Connectors Management Scripts

This directory contains scripts for managing Kafka Connect Debezium connectors and topics in Kubernetes environments.

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

`common.sh` - Shared functions and utilities used by all scripts:
- Environment file loading and validation
- Kubernetes context checking
- Credential fetching from secrets
- Kafka command execution via pods
- Port forwarding management
- Output formatting and logging

## Scripts

### Topic Management

#### `manage-topics.sh`
Unified script for all topic operations (list, create, update, delete).

```bash
# List all topics
./manage-topics.sh --env .sbx-uat.env list

# List topics with details
./manage-topics.sh --env .sbx-uat.env list --details

# List topics matching pattern
./manage-topics.sh --env .sbx-uat.env list --filter "^sbx_uat.wms.*"

# Create a topic
./manage-topics.sh --env .sbx-uat.env create --topic test-topic --partitions 3

# Create topic with configs
./manage-topics.sh --env .sbx-uat.env create --topic important-topic \
  --config retention.ms=-1 --config compression.type=lz4

# Update topic to infinite retention
./manage-topics.sh --env .sbx-uat.env update --filter "^test-topic$" --cleanup-policy infinite

# Update specific configs
./manage-topics.sh --env .sbx-uat.env update --filter "^test-.*" --config compression.type=snappy

# Delete topics matching pattern
./manage-topics.sh --env .sbx-uat.env delete --filter "^test-.*"

# Delete with dry-run
./manage-topics.sh --env .sbx-uat.env delete --filter "^temp-.*" --dry-run
```

Features:
- **list**: View topics with optional filtering and details
- **create**: Create new topics with custom configurations
- **update**: Modify topic configurations in bulk
- **delete**: Remove topics with pattern matching and safety checks
- **--dry-run**: Preview changes without applying them
- **Protection**: Signal topics and internal Kafka topics are protected from deletion

### Debezium Connectors

#### `wms-debezium-postgres.sh`
Deploy WMS Postgres Debezium connector.

```bash
./wms-debezium-postgres.sh --env .sbx-uat.env
```

#### `encarta-debezium-postgres.sh`
Deploy Encarta Postgres Debezium connector.

```bash
./encarta-debezium-postgres.sh --env .sbx-uat.env
```

#### `backbone-debezium-postgres.sh`
Deploy Backbone Postgres Debezium connector.

```bash
./backbone-debezium-postgres.sh --env .sbx-uat.env
```

### Signal Topics

#### `create-signal-topics.sh`
Create Debezium signal topics for incremental snapshots.

```bash
./create-signal-topics.sh --env .sbx-uat.env
```

Creates signal topics for:
- WMS connector
- Encarta connector
- Backbone connector

### Incremental Snapshots

#### `trigger-snapshots.sh`
Trigger incremental snapshots for specific tables.

```bash
# Trigger snapshot for specific table
./trigger-snapshots.sh --env .sbx-uat.env --connector wms --table public.inventory

# Trigger snapshots for multiple tables
./trigger-snapshots.sh --env .sbx-uat.env --connector wms \
  --table public.inventory \
  --table public.task \
  --table public.order

# Use from file
./trigger-snapshots.sh --env .sbx-uat.env --connector wms --from-file tables.txt
```

Features:
- Single or multiple table snapshots
- Custom ORDER BY clauses for specific tables
- Batch processing from file
- Automatic signal topic validation

### Schema Management

#### `delete-schema.sh`
Delete schemas from Schema Registry.

```bash
# Delete schemas matching pattern
./delete-schema.sh --env .sbx-uat.env --filter "^test-.*"

# Dry run mode
./delete-schema.sh --env .sbx-uat.env --filter "^temp-.*" --dry-run

# Force deletion without confirmation
./delete-schema.sh --env .sbx-uat.env --filter "^old-.*" --force
```

## SQL Files

- `wms-publications.sql` - WMS database publication configuration
- `encarta-publications.sql` - Encarta database publication configuration
- `backbone-publications.sql` - Backbone database publication configuration

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
DEBUG=true ./manage-topics.sh --env .sbx-uat.env list
```

Check pod logs:
```bash
kubectl logs -n <namespace> <pod-name>
```

Verify connectivity:
```bash
kubectl exec -n <namespace> <pod-name> -- curl -s $KAFKA_REST_URL/topics
```