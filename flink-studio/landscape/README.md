# Flink Landscape SQL Management

This directory contains tools and SQL files for managing Flink table definitions and data operations across different environments.

## Directory Structure

```
landscape/
├── README.md                    # This file
├── config.yaml                  # Configuration file
├── requirements.txt             # Python dependencies
├── flink_sql_executor.py        # Main Python executor script
├── run_sql_executor.sh          # Bash wrapper script
├── sbx-uat/                     # Environment-specific SQL files
│   └── *.sql                    # SQL files for sbx-uat environment
├── prod/                        # Production SQL files (if any)
│   └── *.sql                    # SQL files for production environment
└── scripts/                     # Additional utility scripts
```

## SQL File Organization

SQL files in each environment directory are executed in the following order:

1. **DDL Files**: Files containing "ddl" in the name (table definitions, schemas)
2. **Other SQL Files**: Insert statements, view definitions, etc.

Within each category, files are executed alphabetically.

## Features

### Flink SQL Executor (`flink_sql_executor.py`)

A comprehensive Python script that:

- ✅ **Session Management**: Creates and manages Flink SQL Gateway sessions
- ✅ **Status Monitoring**: Real-time status checking with detailed progress reporting
- ✅ **Error Handling**: Comprehensive error reporting with debug information
- ✅ **File Organization**: Automatic execution order (DDL first, then other files)
- ✅ **Dry Run Support**: Preview what would be executed without running SQL
- ✅ **Flexible Configuration**: Command-line arguments and config file support
- ✅ **Logging**: Configurable logging levels with optional file output
- ✅ **Timeout Handling**: Configurable timeouts for long-running operations

### Runner Script (`run_sql_executor.sh`)

A bash wrapper that:

- ✅ **Environment Setup**: Automatically creates Python virtual environment
- ✅ **Dependency Management**: Installs required Python packages
- ✅ **Connectivity Check**: Verifies Flink SQL Gateway accessibility
- ✅ **User-Friendly Interface**: Colored output and clear status messages
- ✅ **Parameter Validation**: Validates environments and required parameters

## Usage

### Quick Start

```bash
# Execute SQL files for sbx-uat environment
./run_sql_executor.sh --environment sbx-uat

# Dry run to see what would be executed
./run_sql_executor.sh --environment sbx-uat --dry-run

# Use custom SQL Gateway URL (e.g., port-forwarded)
./run_sql_executor.sh --environment sbx-uat --url http://localhost:8083

# Enable verbose logging with file output
./run_sql_executor.sh --environment sbx-uat --verbose --log-file execution.log
```

### Direct Python Usage

```bash
# Install dependencies first
pip install -r requirements.txt

# Execute SQL files
python3 flink_sql_executor.py --environment sbx-uat

# With custom SQL Gateway URL
python3 flink_sql_executor.py --environment sbx-uat --sql-gateway-url http://localhost:8083

# Dry run with debug logging
python3 flink_sql_executor.py --environment sbx-uat --dry-run --log-level DEBUG
```

## Configuration

### Command Line Options

#### Runner Script (`run_sql_executor.sh`)

```bash
Options:
    -e, --environment ENV     Environment to execute (required)
    -u, --url URL            SQL Gateway URL (default: http://localhost:8083)
    -d, --dry-run            Show what would be executed without running
    -v, --verbose            Enable verbose logging (DEBUG level)
    -l, --log-file FILE      Log to file
    -h, --help               Show help message
```

#### Python Script (`flink_sql_executor.py`)

```bash
Options:
    --environment, -e        Environment name (required)
    --sql-gateway-url        Flink SQL Gateway URL
    --landscape-path         Path to landscape directory
    --dry-run               Preview mode without execution
    --log-level             Logging level (DEBUG, INFO, WARNING, ERROR)
    --log-file              Log file path
```

### Configuration File (`config.yaml`)

The script supports configuration via `config.yaml` file:

```yaml
sql_gateway:
  url: "http://localhost:8083"
  session_timeout: 300

environments:
  sbx-uat:
    description: "Sandbox UAT environment"
  prod:
    description: "Production environment"

logging:
  level: "INFO"
  format: "%(asctime)s - %(levelname)s - %(message)s"
```

## Examples

### Basic Execution

```bash
# Execute all SQL files for sbx-uat environment
./run_sql_executor.sh --environment sbx-uat
```

Expected output:
```
ℹ Starting Flink SQL Executor for environment: sbx-uat
ℹ SQL Gateway URL: http://localhost:8083
ℹ Creating Python virtual environment...
✓ Virtual environment created
✓ Dependencies installed
✓ Flink SQL Gateway is accessible
ℹ Executing SQL files...
✓ backbone_public_node_ddl.sql completed successfully (2.3s)
🎉 Execution completed successfully!
```

### Dry Run

```bash
# Preview what would be executed
./run_sql_executor.sh --environment sbx-uat --dry-run
```

Expected output:
```
ℹ Starting Flink SQL Executor for environment: sbx-uat
⚠ Flink SQL Gateway is not accessible at http://localhost:8083
ℹ Found 1 SQL files to execute
ℹ DRY RUN: Would execute backbone_public_node_ddl.sql (2847 chars)
✓ All 1 SQL files executed successfully
🎉 Execution completed successfully!
```

### With Custom SQL Gateway

```bash
# If using port forwarding to access Flink SQL Gateway
kubectl port-forward svc/flink-sql-gateway 8083:8083 &
./run_sql_executor.sh --environment sbx-uat --url http://localhost:8083
```

## Prerequisites

### Flink Cluster Setup

1. **Flink SQL Gateway**: Must be running and accessible
2. **Required Connectors**: Kafka connector, Avro connector must be available in Flink classpath
3. **Network Access**: The script must be able to reach the SQL Gateway URL

### Local Setup

1. **Python 3.7+**: Required for the executor script
2. **pip**: For installing Python dependencies
3. **curl**: For connectivity checks (installed by default on most systems)

### Kubernetes Environment

If running against a Kubernetes-deployed Flink cluster:

```bash
# Port forward to access SQL Gateway
kubectl port-forward svc/flink-sql-gateway 8083:8083

# Run in another terminal
./run_sql_executor.sh --environment sbx-uat --url http://localhost:8083
```

## Troubleshooting

### Common Issues

#### 1. SQL Gateway Not Accessible

```
✗ Flink SQL Gateway is not accessible at http://localhost:8083
```

**Solutions:**
- Check if Flink cluster is running: `kubectl get pods -l app=flink`
- Verify SQL Gateway service: `kubectl get svc flink-sql-gateway`
- Port forward if needed: `kubectl port-forward svc/flink-sql-gateway 8083:8083`
- Check firewall/network connectivity

#### 2. Session Creation Failed

```
✗ Failed to create session: 500 - Internal Server Error
```

**Solutions:**
- Check Flink cluster logs: `kubectl logs -l app=flink`
- Verify Flink configuration and available resources
- Ensure required connectors are in classpath

#### 3. SQL Execution Failed

```
✗ backbone_public_node_ddl.sql failed: Table already exists
```

**Solutions:**
- Use `DROP TABLE IF EXISTS` in DDL files
- Check existing tables: Connect to Flink SQL Gateway and run `SHOW TABLES;`
- Review SQL syntax for Flink compatibility

#### 4. Python Dependencies

```
ModuleNotFoundError: No module named 'requests'
```

**Solutions:**
- Use the runner script which handles dependencies automatically
- Or manually install: `pip install -r requirements.txt`

### Debug Mode

Enable debug logging for detailed execution information:

```bash
./run_sql_executor.sh --environment sbx-uat --verbose --log-file debug.log
```

This will show:
- Detailed HTTP requests/responses
- SQL Gateway session information
- Step-by-step execution progress
- Timing information for each operation

### Manual Verification

To manually verify SQL Gateway connectivity:

```bash
# Check if SQL Gateway is running
curl -s http://localhost:8083/v1/info | jq .

# Create a test session
curl -X POST http://localhost:8083/v1/sessions \
  -H "Content-Type: application/json" \
  -d '{"properties": {"execution.runtime-mode": "streaming"}}'
```

## SQL File Guidelines

### DDL Files (Table Definitions)

- Name files with "ddl" in the name: `*_ddl.sql`, `*-ddl.sql`
- Include `IF NOT EXISTS` for idempotent execution
- Use appropriate data types for Flink SQL
- Include watermarks for event-time processing

Example:
```sql
CREATE TABLE IF NOT EXISTS backbone_public_node (
    -- table definition
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'format' = 'avro'
    -- connector properties
);
```

### Insert/Query Files

- Name without "ddl": `populate_*.sql`, `insert_*.sql`
- Use appropriate execution mode (batch vs streaming)
- Consider resource requirements for large datasets

## Integration with CI/CD

The SQL executor can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions step
- name: Deploy Flink SQL
  run: |
    # Port forward to Flink cluster
    kubectl port-forward svc/flink-sql-gateway 8083:8083 &
    
    # Wait for port forward
    sleep 5
    
    # Execute SQL files
    ./landscape/run_sql_executor.sh --environment ${{ env.ENVIRONMENT }}
```

## Contributing

When adding new SQL files:

1. Place files in appropriate environment directory
2. Use descriptive names that indicate execution order if needed
3. Test with dry-run first: `./run_sql_executor.sh --environment ENV --dry-run`
4. Verify execution: `./run_sql_executor.sh --environment ENV`