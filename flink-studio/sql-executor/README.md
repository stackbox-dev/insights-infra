# Flink SQL Executor

This directory contains tools for executing SQL files and inline queries against the Flink SQL Gateway.

## Directory Structure

```
sql-executor/
├── README.md                    # This file
├── config.yaml                  # Configuration file
├── requirements.txt             # Python dependencies
├── flink_sql_executor.py        # Main Python executor script
├── run_sql_executor.sh          # Bash wrapper script
├── test.sql                     # Test SQL file
└── sbx-uat/                     # Environment-specific configurations
```

## Features

### Flink SQL Executor (`flink_sql_executor.py`)

A comprehensive Python script that:

- ✅ **Session Management**: Creates and manages Flink SQL Gateway sessions
- ✅ **Status Monitoring**: Real-time status checking with detailed progress reporting
- ✅ **Error Handling**: Comprehensive error reporting with debug information
- ✅ **File Execution**: Execute SQL from individual file paths
- ✅ **Inline Queries**: Execute SQL queries directly from command line
- ✅ **Multi-Statement Support**: Execute multiple SQL statements from a single file or string
- ✅ **Smart SQL Parsing**: Handles comments, string literals, and semicolon separators intelligently
- ✅ **Flexible Error Handling**: Continue on error or stop on first failure
- ✅ **Dry Run Support**: Preview what would be executed without running SQL
- ✅ **Flexible Configuration**: Command-line arguments and config file support
- ✅ **Logging**: Configurable logging levels with optional file output
- ✅ **Timeout Handling**: Configurable timeouts for long-running operations

## Multi-Statement Support

The Flink SQL Executor now supports executing multiple SQL statements from a single file or inline string. This is particularly useful for:

- **Database setup scripts** with table creation and data population
- **Complex data pipelines** requiring multiple transformation steps  
- **Batch processing** of related SQL operations

### How it works

- **Single session**: Creates one Flink SQL Gateway session and reuses it for all statements
- **Smart parsing**: Automatically splits SQL content on semicolons while respecting string literals and comments
- **Comment handling**: Removes both `--` single-line and `/* */` multi-line comments
- **String literal safety**: Preserves semicolons inside quoted strings (`'text; with semicolon'`)
- **Error handling**: Configurable behavior when individual statements fail
- **State preservation**: Variables, temporary tables, and session configuration persist across statements

### Examples

```sql
-- Example multi-statement file (setup.sql)
-- All statements run in the same session, preserving state

-- Set session configuration
SET 'sql-client.execution.result-mode' = 'table';

-- Create a source table
CREATE TABLE orders (
    order_id INT,
    customer_id INT,
    amount DOUBLE
) WITH (
    'connector' = 'datagen'
);

-- Create an aggregation table (references the table created above)
CREATE TABLE daily_totals AS
SELECT 
    DATE_FORMAT(NOW(), 'yyyy-MM-dd') as date,
    COUNT(*) as order_count,
    SUM(amount) as total_amount
FROM orders;

-- Query the results (uses both tables created in the same session)
SELECT * FROM daily_totals;
```

```bash
# Execute multiple statements (default behavior)
python flink_sql_executor.py --file setup.sql

# Execute as single statement (legacy mode)
python flink_sql_executor.py --file setup.sql --single-statement

# Stop on first error instead of continuing
python flink_sql_executor.py --file setup.sql --stop-on-error

# Execute multiple inline statements
python flink_sql_executor.py --sql "CREATE TABLE test AS SELECT 1; SELECT * FROM test;"
```

### Session Advantages

Using a single session for all statements provides several benefits:

1. **State Preservation**: Variables, temporary tables, and configurations persist across statements
2. **Performance**: Eliminates overhead of creating/destroying sessions for each statement  
3. **Dependencies**: Later statements can reference objects created by earlier statements
4. **Consistency**: All statements execute in the same Flink execution environment
5. **Resource Efficiency**: Reduces load on the Flink SQL Gateway

### Execution Flow

```
1. Create single Flink SQL Gateway session
2. Parse SQL file/string into individual statements  
3. Execute each statement sequentially using the same session
4. Collect results and handle errors per statement
5. Close session when all statements complete
```

### Runner Script (`run_sql_executor.sh`)

A bash wrapper that:

- ✅ **Environment Setup**: Automatically creates Python virtual environment
- ✅ **Dependency Management**: Installs required Python packages
- ✅ **Connectivity Check**: Verifies Flink SQL Gateway accessibility
- ✅ **User-Friendly Interface**: Colored output and clear status messages
- ✅ **Parameter Validation**: Validates file paths and required parameters

## Usage

### Quick Start

```bash
# Execute SQL from a specific file
./run_sql_executor.sh --file /path/to/my_query.sql

# Execute inline SQL query
./run_sql_executor.sh --sql "SELECT * FROM my_table LIMIT 10"

# Dry run to see what would be executed
./run_sql_executor.sh --file my_query.sql --dry-run

# Use custom SQL Gateway URL (e.g., port-forwarded)
./run_sql_executor.sh --file my_query.sql --url http://localhost:8083

# Enable verbose logging with file output
./run_sql_executor.sh --file my_query.sql --verbose --log-file execution.log
```

### Direct Python Usage

```bash
# Install dependencies first
pip install -r requirements.txt

# Execute SQL from a specific file (supports multiple statements)
python3 flink_sql_executor.py --file /path/to/my_query.sql

# Execute multiple inline SQL statements
python3 flink_sql_executor.py --sql "CREATE TABLE test AS SELECT 1; SELECT * FROM test;"

# Execute as single statement (disable multi-statement parsing)
python3 flink_sql_executor.py --file my_query.sql --single-statement

# Stop on first error instead of continuing
python3 flink_sql_executor.py --file my_query.sql --stop-on-error

# With custom SQL Gateway URL
python3 flink_sql_executor.py --file my_query.sql --sql-gateway-url http://localhost:8083

# Dry run with debug logging
python3 flink_sql_executor.py --file my_query.sql --dry-run --log-level DEBUG
```

## Configuration

### Command Line Options

#### Runner Script (`run_sql_executor.sh`)

```bash
Options:
    -f, --file FILE           SQL file to execute
    -s, --sql QUERY          Inline SQL query to execute
    -u, --url URL            SQL Gateway URL (overrides config.yaml)
    -d, --dry-run            Show what would be executed without running
    -v, --verbose            Enable verbose logging (DEBUG level)
    -l, --log-file FILE      Log to file
    -h, --help               Show help message
```

**Note**: If `--url` is not specified, the runner script will use the URL from `config.yaml`.

#### Python Script (`flink_sql_executor.py`)

```bash
Options:
    --file, -f              Path to SQL file to execute
    --sql, -s               Inline SQL query to execute
    --sql-gateway-url        Flink SQL Gateway URL
    --dry-run               Preview mode without execution
    --debug                 Enable debug mode with detailed error information
    --log-level             Logging level (DEBUG, INFO, WARNING, ERROR)
    --log-file              Log file path
    --continue-on-error     Continue executing remaining statements when one fails (default: True)
    --stop-on-error         Stop execution on first error (overrides --continue-on-error)
    --single-statement      Treat input as a single statement (don't parse multiple statements)
    --config                Configuration file path (default: config.yaml)
```

### Configuration File (`config.yaml`)

The script automatically loads configuration from `config.yaml` in the same directory. Configuration values serve as defaults that can be overridden by command-line arguments.

**Current configuration** (as loaded from your `config.yaml`):

```yaml
sql_gateway:
  # Flink SQL Gateway URL - used as default if not specified via --url
  url: "http://flink-sql-gateway.flink-studio.api.staging.stackbox.internal"
  
  # Session timeout in seconds
  session_timeout: 300
  
  # Operation polling settings
  poll_interval: 2
  max_wait_time: 60

logging:
  # Default logging level
  level: "INFO"
  
  # Log format
  format: "%(asctime)s - %(levelname)s - %(message)s"

execution:
  # Continue executing if errors occur
  continue_on_error: true

connection:
  # Request timeout in seconds
  timeout: 30
  
  # Number of retries for failed requests
  retry_count: 3
  
  # Retry delay in seconds
  retry_delay: 5
```

**Configuration Priority** (highest to lowest):
1. Command-line arguments (e.g., `--sql-gateway-url`, `--log-level`)
2. Configuration file values (`config.yaml`)
3. Built-in defaults

## Error Handling

The SQL executor provides enhanced error formatting to help debug SQL issues:

### Normal Error Mode (Default)
Shows concise, user-friendly error messages:

```
❌ Encountered "current_time" at line 3, column 29.
```

### Debug Mode (`--debug` flag)
Shows detailed error information with suggestions:

```
╭─ SQL Parse Error ─────────────────────────────────────────────────────────╮
│ Encountered "current_time" at line 3, column 29.
│ 
│ This usually means:
│ • Invalid SQL syntax
│ • Reserved keyword used as identifier (try adding quotes)
│ • Missing quotes around string literals
│ • Incorrect table/column names
│ 
│ Suggestion: Check your SQL syntax and ensure all identifiers are properly quoted
╰───────────────────────────────────────────────────────────────────────────╯
```

### Error Types Detected
- **SQL Parse Errors**: Syntax issues, reserved keywords, etc.
- **Table Not Found**: Missing or incorrectly named tables
- **General SQL Errors**: Connection issues, data type mismatches, etc.

### Usage
```bash
# Basic error reporting
./run_sql_executor.sh --file problematic_query.sql

# Detailed error debugging  
./run_sql_executor.sh --file problematic_query.sql --debug
```

## Examples

### Basic SQL File Execution

```bash
# Execute SQL from a file (uses config.yaml URL automatically)
./run_sql_executor.sh --file my_query.sql
```

Expected output:

```
ℹ Starting Flink SQL Executor for SQL file: /path/to/my_query.sql
ℹ SQL Gateway URL: http://flink-sql-gateway.flink-studio.api.staging.stackbox.internal
ℹ Creating Python virtual environment...
✓ Virtual environment created
✓ Dependencies installed
✓ Flink SQL Gateway is accessible
ℹ Executing SQL file...
✓ my_query.sql completed successfully (2.3s)
🎉 Execution completed successfully!
```

### Dry Run

```bash
# Preview what would be executed
./run_sql_executor.sh --file my_query.sql --dry-run
```

Expected output:

```
ℹ Starting Flink SQL Executor for SQL file: /path/to/my_query.sql
⚠ Flink SQL Gateway is not accessible at http://localhost:8083
ℹ DRY RUN: Would execute SQL from my_query.sql
ℹ SQL content (150 characters):
ℹ SELECT 'Hello from file!' as message, CURRENT_TIMESTAMP as execution_time;
🎉 Dry run completed successfully!
```

### With Custom SQL Gateway

```bash
# If using port forwarding to access Flink SQL Gateway
kubectl port-forward svc/flink-sql-gateway 8083:8083 &
./run_sql_executor.sh --file my_query.sql --url http://localhost:8083
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
./run_sql_executor.sh --file my_query.sql --url http://localhost:8083
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
./run_sql_executor.sh --file my_query.sql --verbose --log-file debug.log
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
    ./flink-studio/sql-executor/run_sql_executor.sh --file my_deployment_queries.sql
```

## Contributing

When adding new SQL files:

1. Create descriptive SQL file names that indicate their purpose
2. Test with dry-run first: `./run_sql_executor.sh --file my_query.sql --dry-run`
3. Verify execution: `./run_sql_executor.sh --file my_query.sql`
