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
└── sbx-uat/                     # Environment-specific SQL scripts
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
./run_sql_executor.sh --file setup.sql

# Execute as single statement (legacy mode)
./run_sql_executor.sh --file setup.sql --single-statement

# Stop on first error instead of continuing
./run_sql_executor.sh --file setup.sql --stop-on-error

# Execute multiple inline statements
./run_sql_executor.sh --sql "CREATE TABLE test AS SELECT 1; SELECT * FROM test;"
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

A simplified bash wrapper that focuses solely on environment setup:

- ✅ **Environment Setup**: Automatically creates Python virtual environment
- ✅ **Dependency Management**: Installs required Python packages
- ✅ **Pass-Through Arguments**: All command-line options are passed directly to Python script
- ✅ **User-Friendly Interface**: Colored output and clear status messages

The bash script is now streamlined - it only handles Python environment setup and passes all arguments to the Python script for processing. This eliminates code duplication and ensures consistent behavior.

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

# Show running Flink jobs
./run_sql_executor.sh --sql "SHOW JOBS"

# Stop a specific Flink job (replace with actual job ID)
./run_sql_executor.sh --sql "STOP JOB '1234567890abcdef'"

# List all tables in the catalog
./run_sql_executor.sh --sql "SHOW TABLES"

# Describe a specific table structure
./run_sql_executor.sh --sql "DESCRIBE my_table"
```

## Configuration

### Command Line Options

All command-line arguments are handled by the Python script. The bash wrapper (`run_sql_executor.sh`) passes all arguments directly to `flink_sql_executor.py`.

#### Available Options

```bash
Options:
    --file, -f FILE          Path to SQL file to execute
    --sql, -s SQL            Inline SQL query to execute
    --sql-gateway-url URL    Flink SQL Gateway URL (default from config.yaml)
    --url, -u URL            Alias for --sql-gateway-url (bash script compatibility)
    --dry-run, -d            Show what would be executed without running
    --debug                  Enable debug mode with detailed error information
    --verbose, -v            Enable verbose logging (DEBUG level)
    --log-level LEVEL        Logging level (DEBUG, INFO, WARNING, ERROR)
    --log-file, -l FILE      Log file path (optional)
    --continue-on-error      Continue executing remaining statements when one fails (default)
    --stop-on-error          Stop execution on first error
    --single-statement       Treat input as a single statement (don't parse multiple statements)
    --format FORMAT          Output format: table, simple, plain, json (default: table)
    --json                   Output results in JSON format (equivalent to --format json)
    --keep-session           Keep the SQL Gateway session open after execution
    --config CONFIG          Configuration file path (default: config.yaml)
    --help, -h               Show help message
```

#### Usage Examples

```bash
# Basic file execution
./run_sql_executor.sh --file my_query.sql

# Inline SQL with custom URL
./run_sql_executor.sh --sql "SHOW JOBS" --url http://localhost:8083

# Dry run with verbose logging
./run_sql_executor.sh --file setup.sql --dry-run --verbose

# JSON output format
./run_sql_executor.sh --sql "SELECT * FROM orders LIMIT 5" --json

# Stop on first error
./run_sql_executor.sh --file migration.sql --stop-on-error
```

## Flink Job Management

The SQL executor can be used to manage Flink jobs and inspect the Flink cluster state using standard Flink SQL commands.

### Common Job Management Commands

#### Show Running Jobs

```bash
# List all currently running jobs
./run_sql_executor.sh --sql "SHOW JOBS"
```

Expected output:

```
╭────────────────────────────────────────────────────────────────────────────╮
│ job_id                           │ job_name        │ status  │ start_time  │
├──────────────────────────────────┼─────────────────┼─────────┼─────────────┤
│ a1b2c3d4e5f67890123456789012345  │ my_streaming_job│ RUNNING │ 2024-01-15..│
│ b2c3d4e5f6789012345678901234568a │ data_pipeline   │ RUNNING │ 2024-01-15..│
╰────────────────────────────────────────────────────────────────────────────╯
```

#### Stop a Running Job

```bash
# Stop a specific job (replace with actual job ID from SHOW JOBS)
./run_sql_executor.sh --sql "STOP JOB 'a1b2c3d4e5f6789012345678901234567'"

# Stop a job with a savepoint (recommended for production)
./run_sql_executor.sh --sql "STOP JOB 'a1b2c3d4e5f6789012345678901234567' WITH SAVEPOINT"
```

Expected output:

```
✓ Job 'a1b2c3d4e5f6789012345678901234567' stopped successfully
```

#### Cancel a Job (Force Stop)

```bash
# Cancel a job immediately (without savepoint)
./run_sql_executor.sh --sql "CANCEL JOB 'a1b2c3d4e5f6789012345678901234567'"
```

⚠️ **Warning**: `CANCEL JOB` stops a job immediately without creating a savepoint. Use `STOP JOB` for graceful shutdown.

### Catalog and Table Management

#### List Available Tables

```bash
# Show all tables in the current catalog
./run_sql_executor.sh --sql "SHOW TABLES"

# Show tables in a specific database
./run_sql_executor.sh --sql "SHOW TABLES FROM my_database"
```

#### Describe Table Schema

```bash
# Show detailed information about a table
./run_sql_executor.sh --sql "DESCRIBE my_table"

# Show extended information including table properties
./run_sql_executor.sh --sql "DESCRIBE EXTENDED my_table"
```

#### List Databases and Catalogs

```bash
# Show available databases
./run_sql_executor.sh --sql "SHOW DATABASES"

# Show available catalogs
./run_sql_executor.sh --sql "SHOW CATALOGS"

# Show current catalog and database
./run_sql_executor.sh --sql "SHOW CURRENT CATALOG"
./run_sql_executor.sh --sql "SHOW CURRENT DATABASE"
```

### Function and Module Management

```bash
# Show user-defined functions
./run_sql_executor.sh --sql "SHOW FUNCTIONS"

# Show system functions
./run_sql_executor.sh --sql "SHOW FULL FUNCTIONS"

# Show loaded modules
./run_sql_executor.sh --sql "SHOW MODULES"
```

### Job Management Examples

#### Complete Job Lifecycle Example

```bash
# 1. Check current running jobs
./run_sql_executor.sh --sql "SHOW JOBS"

# 2. Start a new streaming job by running a SQL file
./run_sql_executor.sh --file my_streaming_job.sql

# 3. Monitor the job (check if it's running)
./run_sql_executor.sh --sql "SHOW JOBS"

# 4. Stop the job gracefully when needed
./run_sql_executor.sh --sql "STOP JOB 'YOUR_JOB_ID_HERE' WITH SAVEPOINT"
```

#### Batch Job Management

```bash
# List tables available for batch processing
./run_sql_executor.sh --sql "SHOW TABLES"

# Run a batch job (INSERT INTO statement)
./run_sql_executor.sh --sql "INSERT INTO target_table SELECT * FROM source_table WHERE date = '2024-01-15'"

# Check job status (batch jobs typically complete quickly)
./run_sql_executor.sh --sql "SHOW JOBS"
```

### Advanced Job Management

#### Job Information and Monitoring

```bash
# Show job execution plan (for debugging)
./run_sql_executor.sh --sql "EXPLAIN PLAN FOR SELECT * FROM my_table"
```

#### Session Management

```bash
# Set session properties for job execution
./run_sql_executor.sh --sql "SET 'execution.runtime-mode' = 'batch'"

# Show current session properties
./run_sql_executor.sh --sql "SHOW PROPERTIES"

# Reset a session property
./run_sql_executor.sh --sql "RESET 'execution.runtime-mode'"
```

### Job Management Best Practices

1. **Always use SHOW JOBS first** to see current job state before making changes
2. **Use STOP JOB WITH SAVEPOINT** for production jobs to enable recovery
3. **Use meaningful job names** when creating jobs for easier identification
4. **Monitor job status** after starting new jobs to ensure they're running correctly
5. **Use dry-run mode** to validate SQL before execution:
   ```bash
   ./run_sql_executor.sh --sql "STOP JOB 'my-job-id'" --dry-run
   ```

### Troubleshooting Jobs

#### Check Job Status and Errors

```bash
# Check if jobs are running
./run_sql_executor.sh --sql "SHOW JOBS"

# Look for failed or cancelled jobs in Flink UI
# Access Flink dashboard at: http://your-flink-cluster:8081
```

#### Common Job Issues

1. **Job not starting**: Check table definitions and data sources
2. **Job stuck in "CREATED" state**: Usually indicates resource constraints
3. **Job failing repeatedly**: Check logs in Flink UI for detailed error messages
4. **High checkpoint times**: May indicate performance issues

#### Get Job Details

````bash
# For detailed job information, check the Flink Web UI
# or use the Flink REST API directly:
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
````

**Configuration Priority** (highest to lowest):

1. Command-line arguments (e.g., `--sql-gateway-url`, `--log-level`)
2. Configuration file values (`config.yaml`)
3. Built-in defaults

## Error Handling

The SQL executor provides enhanced error formatting to help debug SQL issues:

### Pretty Error Messages (Default)

Shows user-friendly error messages with helpful context:

```
╭─ SQL Validation Error ────────────────────────────────────────────────────╮
│ SQL validation failed. At line 1, column 15: Object 'x' not found
│
│ This usually means:
│ • Table or column doesn't exist
│ • Data type mismatch
│ • Invalid SQL operation for the context
│
│ 💡 Use --debug for more detailed error information
╰───────────────────────────────────────────────────────────────────────────╯
```

### Debug Mode (`--debug` flag)

Shows detailed error information with full stack traces:

```
╭─ SQL Validation Error ────────────────────────────────────────────────────╮
│ SQL validation failed. At line 1, column 15: Object 'x' not found
│
│ Full error details:
│ org.apache.flink.table.api.ValidationException: Object 'x' not found
│     at org.apache.flink.table.planner.calcite.FlinkPlannerImpl...
│     [full stack trace]
╰───────────────────────────────────────────────────────────────────────────╯
```

### Error Types Detected

- **SQL Validation Errors**: Missing tables/columns, data type issues
- **SQL Parse Errors**: Syntax issues, reserved keywords, malformed queries
- **Table Not Found**: Missing or incorrectly named tables
- **Catalog Errors**: Database/schema configuration issues
- **Connection Errors**: Network and gateway connectivity problems

### Usage

```bash
# Basic error reporting (pretty formatted by default)
./run_sql_executor.sh --sql "SELECT * FROM nonexistent_table"

# Detailed error debugging with full stack traces
./run_sql_executor.sh --sql "SELECT * FROM nonexistent_table" --debug
```

````

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
````

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
ℹ Setting up Python environment...
ℹ Activating virtual environment...
ℹ Installing/updating dependencies...
✓ Dependencies installed
ℹ Executing Flink SQL Executor...
ℹ️  Checking Flink SQL Gateway connectivity at http://flink-sql-gateway.flink-studio.api.staging.stackbox.internal...
✅ Flink SQL Gateway is accessible
2025-01-15 10:30:45,123 - INFO - Executing SQL from file: my_query.sql
2025-01-15 10:30:45,456 - INFO - ✓ SQL Gateway session created: abc123...
2025-01-15 10:30:47,789 - INFO - ✓ my_query.sql completed successfully (2.3s)
✓ SQL execution completed successfully!
```

### Job Management Examples

```bash
# Check running jobs
./run_sql_executor.sh --sql "SHOW JOBS"
```

Expected output:

```
ℹ Setting up Python environment...
✓ Dependencies installed
ℹ Executing Flink SQL Executor...
✅ Flink SQL Gateway is accessible
2025-01-15 10:31:00,123 - INFO - Executing inline SQL query

📊 Results for inline-query_stmt_1:
═══════════════════════════════════════════════════════════════════════════════
┌──────────────────────────────────────┬─────────────────┬─────────┬──────────────┐
│ job_id                               │ job_name        │ status  │ start_time   │
├──────────────────────────────────────┼─────────────────┼─────────┼──────────────┤
│ a1b2c3d4e5f6789012345678901234567890 │ streaming_job_1 │ RUNNING │ 2025-01-15..│
│ b2c3d4e5f6789012345678901234567891a │ batch_job_2     │ RUNNING │ 2025-01-15..│
└──────────────────────────────────────┴─────────────────┴─────────┴──────────────┘

✅ Displayed 2 row(s)
═══════════════════════════════════════════════════════════════════════════════
✓ SQL execution completed successfully!
```

### Dry Run

```bash
# Preview what would be executed
./run_sql_executor.sh --file my_query.sql --dry-run
```

Expected output:

```
ℹ Setting up Python environment...
✓ Dependencies installed
ℹ Executing Flink SQL Executor...
ℹ️  Checking Flink SQL Gateway connectivity at http://flink-sql-gateway.flink-studio.api.staging.stackbox.internal...
✅ Flink SQL Gateway is accessible
2025-01-15 10:32:00,123 - INFO - DRY RUN: Would execute 1 SQL statement(s) from my_query.sql
2025-01-15 10:32:00,124 - INFO -   Statement 1: SELECT 'Hello from file!' as message, CURRENT_TIMESTAMP as execution_time
2025-01-15 10:32:00,125 - INFO - 🎉 Dry run completed successfully!
✓ SQL execution completed successfully!
```

### Job Stopping Example

```bash
# Stop a specific job
./run_sql_executor.sh --sql "STOP JOB 'a1b2c3d4e5f6789012345678901234567890'"
```

Expected output:

```
ℹ Setting up Python environment...
✓ Dependencies installed
ℹ Executing Flink SQL Executor...
✅ Flink SQL Gateway is accessible
2025-01-15 10:33:00,123 - INFO - Executing inline SQL query
2025-01-15 10:33:02,456 - INFO - ✓ Job stopped successfully
✓ SQL execution completed successfully!
```

### JSON Output Format

```bash
# Get job information in JSON format
./run_sql_executor.sh --sql "SHOW JOBS" --json
```

Expected output:

```
ℹ Setting up Python environment...
✓ Dependencies installed
ℹ Executing Flink SQL Executor...
✅ Flink SQL Gateway is accessible

📊 Results for inline-query_stmt_1:
============================================================
[
  {
    "job id": "5fdcdc70a10329b83b2efbc6e35b5d3e",
    "job name": "insert-into_default_catalog.default_database.sbx-uat.backbone.public.node2",
    "status": "RUNNING",
    "start time": "2025-07-28T07:47:00.835Z"
  },
  {
    "job id": "96e328cf92c8966f94e8c33d6ca56d84",
    "job name": "insert-into_default_catalog.default_database.sbx-uat.wms.public.storage_bin_summary",
    "status": "RUNNING",
    "start time": "2025-07-28T07:47:00.355Z"
  },
  {
    "job id": "a9449e3406fb929db932017f96dd4831",
    "job name": "SELECT `sbx-uat_backbone_public_node`.`id`, `sbx-uat_backbone_public_node`.`parentId`...",
    "status": "CANCELED",
    "start time": "2025-07-28T08:53:05.54Z"
  }
]

✅ Displayed 3 row(s) in JSON format
============================================================
✓ SQL execution completed successfully!
```

### With Custom SQL Gateway

```bash
# If using port forwarding to access Flink SQL Gateway
kubectl port-forward svc/flink-sql-gateway 8083:8083 &
./run_sql_executor.sh --sql "SHOW TABLES" --url http://localhost:8083
```

### Error Example

```bash
# Example of error handling with improved formatting
./run_sql_executor.sh --sql "SELECT * FROM nonexistent_table"
```

Expected output:

```
ℹ Setting up Python environment...
✓ Dependencies installed
ℹ Executing Flink SQL Executor...
✅ Flink SQL Gateway is accessible
2025-01-15 10:35:00,123 - ERROR - ✗ inline-query_stmt_1 failed

╭─ SQL Validation Error ────────────────────────────────────────────────────╮
│ SQL validation failed. At line 1, column 15: Object 'nonexistent_table' not found
│
│ This usually means:
│ • Table or column doesn't exist
│ • Data type mismatch
│ • Invalid SQL operation for the context
│
│ 💡 Use --debug for more detailed error information
╰───────────────────────────────────────────────────────────────────────────╯

💥 Statement 1 error:
[Same error message repeated]
✗ SQL execution failed!
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
