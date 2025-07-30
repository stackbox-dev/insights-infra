# Flink SQL Executor

This directory contains comprehensive tools for executing SQL files, managing Flink jobs, and interacting with the Flink SQL Gateway and REST API.

## Directory Structure

```
sql-executor/
├── README.md                    # This file
├── config.yaml                  # Configuration file
├── requirements.txt             # Python dependencies
├── flink_sql_executor.py        # Main Python executor script
├── flink_jobs.db                # SQLite database for operation tracking (auto-created)
├── run_sql_executor.sh          # Bash wrapper script
└── sbx-uat/                     # Environment-specific SQL scripts
```

## Features Overview

### Core SQL Execution (`flink_sql_executor.py`)

A comprehensive Python script with advanced SQL execution capabilities:

- ✅ **Session Management**: Creates and manages Flink SQL Gateway sessions with automatic cleanup
- ✅ **Status Monitoring**: Real-time status checking with detailed progress reporting and timeouts
- ✅ **Advanced Error Handling**: Comprehensive error reporting with debug information and user-friendly formatting
- ✅ **File Execution**: Execute SQL from individual file paths with environment variable substitution
- ✅ **Inline Queries**: Execute SQL queries directly from command line
- ✅ **Multi-Statement Support**: Execute multiple SQL statements from a single file or string with session preservation
- ✅ **Smart SQL Parsing**: Handles comments, string literals, and semicolon separators intelligently
- ✅ **Flexible Error Handling**: Continue on error or stop on first failure modes
- ✅ **Dry Run Support**: Preview what would be executed without running SQL or job operations
- ✅ **Multiple Output Formats**: Table, simple, plain text, and JSON output formats
- ✅ **Environment Variables**: Load and substitute variables from .env files with validation
- ✅ **Flexible Configuration**: Command-line arguments and YAML config file support
- ✅ **Advanced Logging**: Configurable logging levels with optional file output and debug modes
- ✅ **Timeout Handling**: Configurable timeouts for long-running operations with retry logic

### Job Management System

Comprehensive Flink job lifecycle management via REST API with optional operation tracking:

#### Job Operations via REST API
- ✅ **Job Listing**: List all jobs with filtering by status (RUNNING, FINISHED, CANCELED, FAILED, CREATED)
- ✅ **Job Details**: Get comprehensive job information including configuration and metrics
- ✅ **Job Cancellation**: Cancel jobs gracefully with automatic savepoint creation
- ✅ **Status Filtering**: Filter jobs by multiple status conditions with flexible display options

#### Advanced Job Lifecycle Management
- ✅ **Job Pausing**: Pause running jobs by creating savepoints and stopping gracefully
- ✅ **Job Resuming**: Resume paused jobs from their latest savepoints with SQL file execution
- ✅ **Savepoint Operations**: Create, monitor, and manage savepoints with full lifecycle tracking
- ✅ **Operation Tracking**: Optional SQLite database for tracking management operations and savepoint metadata
- ✅ **Savepoint Validation**: Check savepoint usage and prevent conflicts during resume operations

#### Savepoint Management
- ✅ **Savepoint Creation**: Create savepoints for running jobs with custom directory support
- ✅ **Savepoint Monitoring**: Track savepoint creation progress with real-time status updates
- ✅ **Savepoint History**: Maintain complete history of savepoints with metadata and usage tracking
- ✅ **Active Savepoint Tracking**: Monitor in-progress savepoint operations across jobs
- ✅ **Resume from Savepoint**: Resume jobs from specific savepoint IDs with SQL execution

#### Job Discovery and Filtering
- ✅ **Pausable Jobs**: List all jobs that can be paused (currently RUNNING)
- ✅ **Resumable Jobs**: List all jobs that can be resumed (PAUSED with available savepoints)
- ✅ **Job Name Support**: Support job operations using either job ID or job name
- ✅ **Flexible Status Display**: Show jobs by status with customizable limits and sorting

### Database Integration

Optional operation tracking with SQLite for management history:

- ✅ **SQLite Database**: Automatic database creation and schema management
- ✅ **Job Tracking**: Track job management operations (pause, resume, cancel) with metadata
- ✅ **Savepoint Records**: Complete savepoint lifecycle tracking with paths, sizes, and status
- ✅ **Resume Events**: Track all resume operations with source savepoints and target jobs
- ✅ **Data Integrity**: Foreign key constraints and transaction safety for consistent data
- ✅ **Database Queries**: Rich query capabilities for operation history and savepoint analysis

*Note: All job information comes directly from Flink REST API - database only stores operation history*

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

## Usage

### Quick Start Examples

#### Basic SQL Execution
```bash
# Execute SQL from a specific file
./run_sql_executor.sh --file /path/to/my_query.sql

# Execute inline SQL query
./run_sql_executor.sh --sql "SELECT * FROM my_table LIMIT 10"

# Execute multiple statements in sequence (preserves session state)
./run_sql_executor.sh --sql "CREATE TABLE test AS SELECT 1; SELECT * FROM test;"

# Execute with environment variable substitution
./run_sql_executor.sh --file my_query.sql --env-file .production.env

# Dry run to see what would be executed
./run_sql_executor.sh --file my_query.sql --dry-run

# Use custom SQL Gateway URL (e.g., port-forwarded)
./run_sql_executor.sh --file my_query.sql --url http://localhost:8083
```

#### Advanced SQL Options
```bash
# Execute as single statement (disable multi-statement parsing)
./run_sql_executor.sh --file my_query.sql --single-statement

# Stop on first error instead of continuing
./run_sql_executor.sh --file my_query.sql --stop-on-error

# Enable verbose logging with file output
./run_sql_executor.sh --file my_query.sql --verbose --log-file execution.log

# Keep session open for interactive use
./run_sql_executor.sh --sql "CREATE TABLE test AS SELECT 1" --keep-session

# Output in different formats
./run_sql_executor.sh --sql "SELECT * FROM orders LIMIT 5" --format json
./run_sql_executor.sh --sql "SELECT * FROM orders LIMIT 5" --json  # shorthand
./run_sql_executor.sh --sql "SELECT * FROM orders LIMIT 5" --format simple
```

### Job Management

#### Basic Job Operations
```bash
# List all jobs from Flink cluster
./run_sql_executor.sh --list-jobs

# List jobs with specific status
./run_sql_executor.sh --list-jobs --status-filter RUNNING
./run_sql_executor.sh --list-jobs --status-filter FAILED
./run_sql_executor.sh --list-jobs --cancelled  # shorthand for CANCELED

# Show all job statuses (including finished, failed, etc.)
./run_sql_executor.sh --list-jobs --show-all

# Get detailed information about a specific job
./run_sql_executor.sh --job-info a1b2c3d4e5f6789abcdef123456789abcdef1234

# List jobs in JSON format for scripting
./run_sql_executor.sh --list-jobs --json
```

#### Job Lifecycle Management
```bash
# Cancel a job gracefully (creates savepoint automatically)
./run_sql_executor.sh --cancel-job a1b2c3d4e5f6789abcdef123456789abcdef1234

# Pause a job (creates savepoint and stops job)
./run_sql_executor.sh --pause-job a1b2c3d4e5f6  # using job ID
./run_sql_executor.sh --pause-job "my_streaming_job"  # using job name

# Pause with custom savepoint directory
./run_sql_executor.sh --pause-job my_job --savepoint-dir /custom/savepoints

# Resume a paused job from its latest savepoint
./run_sql_executor.sh --resume-job my_job --resume-sql-file /path/to/job.sql

# Resume from a specific savepoint ID
./run_sql_executor.sh --resume-savepoint 42 --resume-sql-file /path/to/job.sql

# Resume with environment variables
./run_sql_executor.sh --resume-job my_job --resume-sql-file job.sql --env-file .prod.env
```

#### Job Discovery
```bash
# List jobs that can be paused (currently RUNNING)
./run_sql_executor.sh --list-pausable

# List jobs that can be resumed (PAUSED with available savepoints)
./run_sql_executor.sh --list-resumable

# List active savepoint operations with their progress
./run_sql_executor.sh --list-active-savepoints

# List savepoint history (newest first, default: top 10)
./run_sql_executor.sh --list-savepoints

# List more savepoints or all savepoints
./run_sql_executor.sh --list-savepoints --limit 50
./run_sql_executor.sh --list-savepoints --limit 0  # show all
```

#### Dry Run Mode (Preview Operations)
```bash
# Preview any operation without executing
./run_sql_executor.sh --file my_query.sql --dry-run
./run_sql_executor.sh --sql "CREATE TABLE test AS SELECT 1" --dry-run
./run_sql_executor.sh --cancel-job my_job --dry-run
./run_sql_executor.sh --pause-job my_job --dry-run
./run_sql_executor.sh --resume-job my_job --resume-sql-file job.sql --dry-run
```

### Database Integration

The executor includes optional database integration for operation tracking:

```bash
# Enable database for operation tracking
./run_sql_executor.sh --list-jobs --enable-database

# Use custom database path
./run_sql_executor.sh --list-jobs --enable-database --db-path /path/to/operations.db

# Disable database (use only REST API)
./run_sql_executor.sh --list-jobs --disable-database
```

### Flink Cluster Inspection

Standard Flink SQL commands for cluster management:

```bash
# Show running jobs (via SQL Gateway)
./run_sql_executor.sh --sql "SHOW JOBS"

# Stop a specific job (replace with actual job ID from SHOW JOBS)
./run_sql_executor.sh --sql "STOP JOB 'a1b2c3d4e5f6789012345678901234567'"

# Stop job with savepoint (recommended for production)
./run_sql_executor.sh --sql "STOP JOB 'a1b2c3d4e5f6789012345678901234567' WITH SAVEPOINT"

# Cancel a job immediately (without savepoint)
./run_sql_executor.sh --sql "CANCEL JOB 'a1b2c3d4e5f6789012345678901234567'"

# List available tables
./run_sql_executor.sh --sql "SHOW TABLES"

# Describe table schema
./run_sql_executor.sh --sql "DESCRIBE my_table"

# Show databases and catalogs
./run_sql_executor.sh --sql "SHOW DATABASES"
./run_sql_executor.sh --sql "SHOW CATALOGS"

# Show current catalog and database
./run_sql_executor.sh --sql "SHOW CURRENT CATALOG"
./run_sql_executor.sh --sql "SHOW CURRENT DATABASE"

# Show functions and modules
./run_sql_executor.sh --sql "SHOW FUNCTIONS"
./run_sql_executor.sh --sql "SHOW MODULES"
```

## Configuration

### Command Line Options

All command-line arguments are handled by the Python script. The bash wrapper (`run_sql_executor.sh`) passes all arguments directly to `flink_sql_executor.py`.

#### Core Execution Options

```bash
# Basic execution
--file, -f FILE          Path to SQL file to execute
--sql, -s SQL            Inline SQL query to execute
--env-file, -e FILE      Environment file for variable substitution (default: .sbx-uat.env)

# SQL Gateway configuration
--sql-gateway-url URL    Flink SQL Gateway URL
--url, -u URL            Alias for --sql-gateway-url (bash script compatibility)

# Execution modes
--dry-run, -d            Show what would be executed without running
--single-statement       Treat input as single statement (disable multi-statement parsing)
--continue-on-error      Continue executing remaining statements when one fails (default)
--stop-on-error          Stop execution on first error

# Output and logging
--format FORMAT          Output format: table, simple, plain, json (default: table)
--json                   Output results in JSON format (equivalent to --format json)
--verbose, -v            Enable verbose logging (DEBUG level)
--log-level LEVEL        Logging level: DEBUG, INFO, WARNING, ERROR
--log-file, -l FILE      Log file path (optional)
--debug                  Enable debug mode with detailed error information

# Session management
--keep-session           Keep SQL Gateway session open after execution
--config CONFIG          Configuration file path (default: config.yaml)
```

#### Job Management Options

```bash
# Job listing and information
--list-jobs              List all jobs from Flink cluster
--job-info JOB_ID        Get detailed information about specific job
--status-filter STATUS   Filter jobs by status (RUNNING, FINISHED, CANCELED, FAILED, CREATED)
--cancelled              Show only cancelled jobs (shortcut for --status-filter CANCELED)
--show-all              Show jobs of all statuses (overrides status filters)

# Job lifecycle operations
--cancel-job JOB_ID      Cancel job gracefully with savepoint
--pause-job JOB_ID       Pause job (create savepoint and stop)
--resume-job JOB_ID      Resume paused job from latest savepoint
--resume-savepoint ID    Resume from specific savepoint ID
--resume-sql-file FILE   SQL file for resume operations (required with resume commands)

# Job discovery
--list-pausable          List jobs that can be paused (RUNNING status)
--list-resumable         List jobs that can be resumed (PAUSED with savepoints)
--list-active-savepoints List active savepoint operations
--list-savepoints        List savepoint history with details
--limit N               Maximum savepoints to display (default: 10, use 0 for all)

# Savepoint configuration
--savepoint-dir PATH     Target directory for savepoint storage

# Database integration
--enable-database        Enable operation database for tracking management operations
--disable-database       Disable operation database - use only REST API
--db-path PATH          Path to SQLite database (default: flink_jobs.db)

# Flink cluster connection
--flink-rest-url URL     Flink REST API URL for job management operations
```

#### Usage Examples by Category

```bash
# Basic SQL execution
./run_sql_executor.sh --file my_query.sql
./run_sql_executor.sh --sql "SELECT * FROM orders LIMIT 10"

# Multi-statement execution with error handling
./run_sql_executor.sh --file setup.sql --stop-on-error
./run_sql_executor.sh --sql "CREATE TABLE test AS SELECT 1; SELECT * FROM test;"

# Environment variable substitution
./run_sql_executor.sh --file my_query.sql --env-file .production.env

# Output formatting
./run_sql_executor.sh --sql "SELECT * FROM orders" --format json
./run_sql_executor.sh --sql "SELECT * FROM orders" --json --verbose

# Job management with operation tracking
./run_sql_executor.sh --list-jobs --enable-database --format json
./run_sql_executor.sh --pause-job my_streaming_job --savepoint-dir /backups

# Dry run for safety
./run_sql_executor.sh --file critical_migration.sql --dry-run --debug
./run_sql_executor.sh --cancel-job production_job --dry-run
```

### Configuration File (`config.yaml`)

The script loads configuration from `config.yaml` in the same directory. Configuration values serve as defaults that can be overridden by command-line arguments.

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

# Job management configuration
job_management:
  # Enable database by default for operation tracking
  enable_database: false
  
  # Default database path for operation history
  database_path: "flink_jobs.db"

# Flink cluster configuration for REST API operations
flink_cluster:
  # Flink REST API URL for job management
  url: "http://flink-jobmanager.flink-studio.api.staging.stackbox.internal:8081"

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

## Advanced Job Management via REST API

Beyond standard Flink SQL commands, the executor provides comprehensive job management through the Flink REST API:

### Job Lifecycle Operations

#### List and Filter Jobs
```bash
# List all jobs with comprehensive details
./run_sql_executor.sh --list-jobs

# Filter by job status
./run_sql_executor.sh --list-jobs --status-filter RUNNING
./run_sql_executor.sh --list-jobs --status-filter FAILED
./run_sql_executor.sh --list-jobs --cancelled  # shorthand for CANCELED

# Show jobs of all statuses (including finished/failed)
./run_sql_executor.sh --list-jobs --show-all

# Output in JSON for scripting
./run_sql_executor.sh --list-jobs --json
```

#### Job Information and Details
```bash
# Get comprehensive job details
./run_sql_executor.sh --job-info a1b2c3d4e5f6789abcdef123456789abcdef1234

# View job configuration, metrics, and execution plan
./run_sql_executor.sh --job-info my_streaming_job --json
```

#### Pause and Resume Operations
```bash
# Pause a running job (creates savepoint and stops)
./run_sql_executor.sh --pause-job my_streaming_job
./run_sql_executor.sh --pause-job a1b2c3d4e5f6  # can use job ID or name

# Pause with custom savepoint directory
./run_sql_executor.sh --pause-job my_job --savepoint-dir /backup/savepoints

# Resume a paused job from its latest savepoint
./run_sql_executor.sh --resume-job my_job --resume-sql-file /path/to/job.sql

# Resume from a specific savepoint by ID
./run_sql_executor.sh --resume-savepoint 42 --resume-sql-file /path/to/job.sql

# Resume with environment variable substitution
./run_sql_executor.sh --resume-job my_job --resume-sql-file job.sql --env-file .prod.env
```

### Savepoint Management

#### Savepoint Operations
```bash
# List all savepoints with detailed information
./run_sql_executor.sh --list-savepoints

# Limit number of savepoints shown
./run_sql_executor.sh --list-savepoints --limit 20
./run_sql_executor.sh --list-savepoints --limit 0  # show all

# List active/in-progress savepoint operations
./run_sql_executor.sh --list-active-savepoints

# List with different output formats
./run_sql_executor.sh --list-savepoints --json --limit 50
```

#### Job Discovery
```bash
# Find jobs that can be paused (currently RUNNING)
./run_sql_executor.sh --list-pausable

# Find jobs that can be resumed (PAUSED with available savepoints)
./run_sql_executor.sh --list-resumable

# Both commands support JSON output for automation
./run_sql_executor.sh --list-pausable --json
./run_sql_executor.sh --list-resumable --json
```

### Database Integration for Operation Tracking

The executor includes optional SQLite database integration for tracking management operations:

```bash
# Enable database for operation tracking
./run_sql_executor.sh --list-jobs --enable-database

# Use custom database file
./run_sql_executor.sh --list-jobs --enable-database --db-path /path/to/custom.db

# Disable database (use only REST API)
./run_sql_executor.sh --list-jobs --disable-database
```

#### Database Features
- **Operation History**: Track job management operations (pause, resume, cancel) over time
- **Savepoint Records**: Complete savepoint lifecycle with metadata
- **Resume Events**: Track all resume operations with source/target relationships
- **Data Integrity**: Foreign key constraints and transaction safety
- **Query Capabilities**: Rich filtering and analysis of operation history

*Note: Job data itself comes directly from Flink REST API - database only stores operation tracking*

### Catalog and Schema Management

Standard Flink SQL commands for cluster inspection:

```bash
# List available tables and databases
./run_sql_executor.sh --sql "SHOW TABLES"
./run_sql_executor.sh --sql "SHOW DATABASES"
./run_sql_executor.sh --sql "SHOW CATALOGS"

# Describe table schema and properties
./run_sql_executor.sh --sql "DESCRIBE my_table"
./run_sql_executor.sh --sql "DESCRIBE EXTENDED my_table"

# Show current context
./run_sql_executor.sh --sql "SHOW CURRENT CATALOG"
./run_sql_executor.sh --sql "SHOW CURRENT DATABASE"

# Function and module management
./run_sql_executor.sh --sql "SHOW FUNCTIONS"
./run_sql_executor.sh --sql "SHOW MODULES"
```
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

## Complete Job Lifecycle Examples

### Production Job Management Workflow

```bash
# 1. Check current cluster status
./run_sql_executor.sh --list-jobs --show-all

# 2. Deploy new streaming job
./run_sql_executor.sh --file streaming_pipeline.sql --env-file .production.env

# 3. Monitor job execution
./run_sql_executor.sh --list-jobs --status-filter RUNNING --json

# 4. Pause job for maintenance (creates savepoint)
./run_sql_executor.sh --pause-job my_streaming_pipeline --savepoint-dir /backups

# 5. Resume job after maintenance
./run_sql_executor.sh --resume-job my_streaming_pipeline --resume-sql-file streaming_pipeline.sql --env-file .production.env

# 6. Check savepoint history
./run_sql_executor.sh --list-savepoints --limit 20 --json
```

### Development and Testing Workflow

```bash
# 1. Dry run to validate SQL before execution
./run_sql_executor.sh --file new_feature.sql --dry-run --debug

# 2. Execute in test environment with detailed logging
./run_sql_executor.sh --file new_feature.sql --verbose --log-file test_execution.log

# 3. Monitor job startup
./run_sql_executor.sh --job-info $(./run_sql_executor.sh --list-jobs --json | jq -r '.[0].job_id')

# 4. Cancel if needed during testing
./run_sql_executor.sh --cancel-job test_job_id --dry-run  # preview first
./run_sql_executor.sh --cancel-job test_job_id  # actual cancel
```

### Batch Processing Workflow

```bash
# 1. Check available tables and schemas
./run_sql_executor.sh --sql "SHOW TABLES"
./run_sql_executor.sh --sql "DESCRIBE my_source_table"

# 2. Execute batch processing with session configuration
./run_sql_executor.sh --sql "SET 'execution.runtime-mode' = 'batch'; INSERT INTO target_table SELECT * FROM source_table WHERE date = '\${PROCESS_DATE}'" --env-file .batch.env

# 3. Monitor batch job completion
./run_sql_executor.sh --list-jobs --status-filter FINISHED
```

## Error Handling and Debugging

The SQL executor provides comprehensive error handling with multiple levels of detail:

### Enhanced Error Formatting

#### Normal Mode (Default)
Shows user-friendly error messages with helpful context:

```bash
./run_sql_executor.sh --sql "SELECT * FROM nonexistent_table"
```

Output:
```
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
```

#### Debug Mode (`--debug` flag)
Shows detailed error information with full stack traces:

```bash
./run_sql_executor.sh --sql "SELECT * FROM nonexistent_table" --debug
```

Output:
```
╭─ SQL Validation Error ────────────────────────────────────────────────────╮
│ SQL validation failed. At line 1, column 15: Object 'nonexistent_table' not found
│
│ Full error details:
│ org.apache.flink.table.api.ValidationException: Object 'nonexistent_table' not found
│     at org.apache.flink.table.planner.calcite.FlinkPlannerImpl...
│     [full stack trace]
╰───────────────────────────────────────────────────────────────────────────╯
```

### Error Types and Solutions

#### SQL Validation Errors
- **Cause**: Missing tables/columns, data type mismatches
- **Solution**: Verify table names and schemas with `SHOW TABLES` and `DESCRIBE table_name`

#### SQL Parse Errors  
- **Cause**: Syntax issues, reserved keywords, malformed queries
- **Solution**: Check SQL syntax, quote identifiers if needed

#### Connection Errors
- **Cause**: Network issues, gateway unavailable
- **Solution**: Check connectivity, verify URLs in config

#### Job Management Errors
- **Cause**: Invalid job IDs, permission issues, cluster problems
- **Solution**: Use `--list-jobs` to verify job IDs, check cluster health

### Debugging Best Practices

```bash
# 1. Always use dry-run for new/critical operations
./run_sql_executor.sh --file critical_operation.sql --dry-run --debug

# 2. Enable verbose logging for troubleshooting
./run_sql_executor.sh --file problem_query.sql --verbose --log-file debug.log

# 3. Test connectivity before complex operations  
./run_sql_executor.sh --sql "SHOW JOBS" --debug

# 4. Use single-statement mode for problematic multi-statement files
./run_sql_executor.sh --file complex_script.sql --single-statement --debug

## Multi-Statement SQL Support

The Flink SQL Executor supports executing multiple SQL statements from a single file or inline string, providing advanced session management and state preservation.

### How Multi-Statement Execution Works

- **Single Session**: Creates one Flink SQL Gateway session and reuses it for all statements
- **Smart Parsing**: Automatically splits SQL content on semicolons while respecting string literals and comments
- **Comment Handling**: Removes both `--` single-line and `/* */` multi-line comments
- **String Literal Safety**: Preserves semicolons inside quoted strings (`'text; with semicolon'`)
- **Error Handling**: Configurable behavior when individual statements fail
- **State Preservation**: Variables, temporary tables, and session configuration persist across statements

### Multi-Statement Examples

#### Database Setup Script
```sql
-- Example multi-statement file (setup.sql)
-- All statements run in the same session, preserving state

-- Create a source table
CREATE TABLE orders (
    order_id INT,
    customer_id INT,
    amount DOUBLE,
    order_time TIMESTAMP(3),
    WATERMARK FOR order_time AS order_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'datagen',
    'number-of-rows' = '1000'
);

-- Create an aggregation table (references the table created above)
CREATE TABLE daily_totals AS
SELECT
    DATE_FORMAT(order_time, 'yyyy-MM-dd') as date,
    COUNT(*) as order_count,
    SUM(amount) as total_amount
FROM orders
GROUP BY DATE_FORMAT(order_time, 'yyyy-MM-dd');

-- Query the results (uses both tables created in the same session)
SELECT * FROM daily_totals;
```

#### Execution Examples
```bash
# Execute multiple statements (default behavior)
./run_sql_executor.sh --file setup.sql

# Execute as single statement (legacy mode)
./run_sql_executor.sh --file setup.sql --single-statement

# Stop on first error instead of continuing
./run_sql_executor.sh --file setup.sql --stop-on-error

# Execute multiple inline statements
./run_sql_executor.sh --sql "CREATE TABLE test AS SELECT 1; SELECT * FROM test;"

# Dry run to preview all statements
./run_sql_executor.sh --file setup.sql --dry-run
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
5. Close session when all statements complete (unless --keep-session)
```

## Environment Variable Substitution

The executor supports environment variable substitution in SQL files and inline queries:

### Environment File Support

```bash
# Use default environment file (.sbx-uat.env)
./run_sql_executor.sh --file my_query.sql

# Use custom environment file
./run_sql_executor.sh --file my_query.sql --env-file .production.env

# Use multiple sources: OS environment + custom file
./run_sql_executor.sh --file my_query.sql --env-file .custom.env
```

### Variable Substitution Syntax

Use `${VARIABLE_NAME}` syntax in SQL files:

```sql
-- Example SQL file with variables
CREATE TABLE orders_${ENVIRONMENT} (
    order_id INT,
    customer_id INT,
    amount DOUBLE
) WITH (
    'connector' = 'kafka',
    'topic' = '${KAFKA_TOPIC}',
    'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
    'format' = 'avro',
    'avro-confluent.url' = '${SCHEMA_REGISTRY_URL}'
);

INSERT INTO orders_${ENVIRONMENT}
SELECT * FROM source_orders 
WHERE date >= '${START_DATE}' AND date <= '${END_DATE}';
```

### Environment File Format

```bash
# .production.env
ENVIRONMENT=prod
KAFKA_TOPIC=orders-production  
KAFKA_BOOTSTRAP_SERVERS=kafka.prod.internal:9092
SCHEMA_REGISTRY_URL=http://schema-registry.prod.internal:8081
START_DATE=2024-01-01
END_DATE=2024-12-31

# Comments are supported
# DEPRECATED_VAR=old_value
```

### Variable Validation

- **Strict Mode**: By default, undefined variables cause execution to fail
- **OS Environment**: Variables from OS environment are automatically available
- **File Override**: Environment file variables override OS variables
- **Error Reporting**: Clear error messages for missing or invalid variables

## Best Practices

### SQL File Organization

#### DDL Files (Table Definitions)
- Name files with "ddl" suffix: `*_ddl.sql`, `*-ddl.sql`
- Include `IF NOT EXISTS` for idempotent execution
- Use appropriate data types for Flink SQL
- Include watermarks for event-time processing

```sql
-- Example: orders_ddl.sql
CREATE TABLE IF NOT EXISTS orders (
    order_id INT,
    customer_id INT,
    amount DOUBLE,
    order_time TIMESTAMP(3),
    WATERMARK FOR order_time AS order_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'orders',
    'format' = 'avro'
);
```

#### DML Files (Data Operations)
- Name without "ddl": `populate_*.sql`, `insert_*.sql`
- Use appropriate execution mode (batch vs streaming)
- Consider resource requirements for large datasets

```sql
-- Example: populate_orders.sql
INSERT INTO orders_summary
SELECT 
    customer_id,
    COUNT(*) as order_count,
    SUM(amount) as total_amount
FROM orders
GROUP BY customer_id;
```

### Production Deployment Guidelines

1. **Always Use Dry Run First**
   ```bash
   ./run_sql_executor.sh --file production_deployment.sql --dry-run --debug
   ```

2. **Enable Database Tracking for Production**
   ```bash
   ./run_sql_executor.sh --file deployment.sql --enable-database --verbose
   ```

3. **Use Environment Files for Configuration**
   ```bash
   ./run_sql_executor.sh --file deployment.sql --env-file .production.env
   ```

4. **Monitor Job Status After Deployment**
   ```bash
   ./run_sql_executor.sh --list-jobs --status-filter RUNNING --json
   ```

5. **Use Savepoints for Job Management**
   ```bash
   ./run_sql_executor.sh --pause-job production_job --savepoint-dir /backups
   ```

### Development and Testing

1. **Use Verbose Logging During Development**
   ```bash
   ./run_sql_executor.sh --file test_query.sql --verbose --log-file dev.log
   ```

2. **Test with Single Statement Mode First**
   ```bash
   ./run_sql_executor.sh --file complex_script.sql --single-statement --debug
   ```

3. **Validate Environment Variables**
   ```bash
   ./run_sql_executor.sh --file my_query.sql --env-file .test.env --dry-run
   ```

4. **Use Stop-on-Error for Critical Operations**
   ```bash
   ./run_sql_executor.sh --file migration.sql --stop-on-error --verbose
   ```
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

## Prerequisites and Setup

### Flink Cluster Requirements

1. **Flink SQL Gateway**: Must be running and accessible at configured URL
2. **Flink REST API**: Required for advanced job management operations  
3. **Required Connectors**: 
   - Kafka connector for streaming data sources
   - Avro connector for schema registry integration
   - Any custom connectors must be available in Flink classpath
4. **Network Access**: The script must be able to reach both SQL Gateway and REST API URLs

### Local Development Setup

1. **Python 3.7+**: Required for the executor script
2. **pip**: For installing Python dependencies  
3. **curl**: For connectivity checks (installed by default on most systems)
4. **jq**: Optional, useful for JSON processing in scripts

### Kubernetes Environment Setup

If running against a Kubernetes-deployed Flink cluster:

```bash
# Port forward to access SQL Gateway
kubectl port-forward svc/flink-sql-gateway 8083:8083 &

# Port forward to access Flink REST API  
kubectl port-forward svc/flink-jobmanager 8081:8081 &

# Run executor with local URLs
./run_sql_executor.sh --file my_query.sql --sql-gateway-url http://localhost:8083 --flink-rest-url http://localhost:8081
```

### Automatic Environment Setup

The runner script (`run_sql_executor.sh`) automatically handles:

- Python virtual environment creation
- Dependency installation from `requirements.txt`
- Environment activation and cleanup

Simply run the script - no manual setup required:

```bash
./run_sql_executor.sh --file my_query.sql
```

## Troubleshooting

### Common Issues and Solutions

#### 1. SQL Gateway Not Accessible
```
✗ Flink SQL Gateway is not accessible at http://localhost:8083
```

**Solutions:**
- Check if Flink cluster is running: `kubectl get pods -l app=flink`
- Verify SQL Gateway service: `kubectl get svc flink-sql-gateway`
- Port forward if needed: `kubectl port-forward svc/flink-sql-gateway 8083:8083`
- Check firewall/network connectivity: `curl http://localhost:8083/v1/info`

#### 2. Flink REST API Connection Failed
```
✗ Failed to connect to Flink REST API at http://localhost:8081
```

**Solutions:**
- Verify Flink JobManager is running: `kubectl get pods -l component=jobmanager`
- Port forward REST API: `kubectl port-forward svc/flink-jobmanager 8081:8081`  
- Check REST API health: `curl http://localhost:8081/config`

#### 3. Session Creation Failed
```
✗ Failed to create session: 500 - Internal Server Error
```

**Solutions:**
- Check Flink cluster logs: `kubectl logs -l app=flink`
- Verify Flink configuration and available resources
- Ensure required connectors are in classpath
- Check TaskManager availability: `kubectl get pods -l component=taskmanager`

#### 4. SQL Execution Failed  
```
✗ backbone_public_node_ddl.sql failed: Table already exists
```

**Solutions:**
- Use `DROP TABLE IF EXISTS` or `CREATE TABLE IF NOT EXISTS` in DDL files
- Check existing tables: `./run_sql_executor.sh --sql "SHOW TABLES"`
- Review SQL syntax for Flink compatibility
- Use dry-run mode to preview: `./run_sql_executor.sh --file my_query.sql --dry-run`

#### 5. Job Management Operations Failed
```
✗ Job not found: my_streaming_job
```

**Solutions:**
- List current jobs: `./run_sql_executor.sh --list-jobs`
- Verify job ID format (use exact job ID from list-jobs output)
- Check if job name vs job ID is being used correctly
- Enable database for job name support: `--enable-database`

#### 6. Savepoint Operations Failed
```
✗ Savepoint creation failed: Insufficient resources
```

**Solutions:**
- Check cluster resources: `kubectl top pods`
- Verify savepoint directory exists and is writable
- Check disk space on Flink cluster nodes
- Use custom savepoint directory: `--savepoint-dir /path/with/space`

#### 7. Environment Variable Substitution Failed
```
✗ Environment variable validation failed: Variable 'KAFKA_TOPIC' not found
```

**Solutions:**
- Check environment file exists: `ls -la .sbx-uat.env`
- Verify variable names match exactly (case sensitive)
- Use dry-run to preview substitution: `--dry-run --debug`
- Check OS environment variables: `env | grep KAFKA_TOPIC`

#### 8. Python Dependencies Issues
```
ModuleNotFoundError: No module named 'requests'
```

**Solutions:**
- Use the runner script which handles dependencies automatically
- Manually install if needed: `pip install -r requirements.txt`
- Check Python version: `python --version` (requires 3.7+)
- Clear virtual environment: `rm -rf venv` and re-run script

### Debug Mode and Logging

Enable comprehensive debugging for troubleshooting:

```bash
# Enable debug logging with file output
./run_sql_executor.sh --file my_query.sql --debug --verbose --log-file debug.log

# Check connectivity with debug info
./run_sql_executor.sh --sql "SHOW JOBS" --debug

# Preview operations without execution  
./run_sql_executor.sh --file complex_operation.sql --dry-run --debug

# Test job management with debug
./run_sql_executor.sh --list-jobs --debug --verbose
```

### Manual Connectivity Verification

To manually verify system connectivity:

```bash
# Test SQL Gateway connectivity
curl -s http://localhost:8083/v1/info | jq .

# Test Flink REST API connectivity  
curl -s http://localhost:8081/config | jq .

# Create a test session manually
curl -X POST http://localhost:8083/v1/sessions \
  -H "Content-Type: application/json" \
  -d '{"properties": {"execution.runtime-mode": "streaming"}}'

# List jobs via REST API
curl -s http://localhost:8081/jobs | jq .
```

### Performance Optimization

For better performance with large operations:

```bash
# Increase timeouts for long-running operations
# Edit config.yaml:
connection:
  timeout: 120  # Increase from default 30 seconds
  retry_count: 5  # Increase retries

# Use single-statement mode for very large SQL files
./run_sql_executor.sh --file large_script.sql --single-statement

# Enable database for better operation tracking
./run_sql_executor.sh --list-jobs --enable-database
```

### Monitoring and Health Checks

Regular health check commands:

```bash
# Check Flink cluster health
./run_sql_executor.sh --sql "SHOW JOBS" --json | jq length

# Verify SQL Gateway responsiveness
time ./run_sql_executor.sh --sql "SELECT 1"

# Check savepoint storage health
./run_sql_executor.sh --list-savepoints --limit 5

# Monitor job management operations
./run_sql_executor.sh --list-active-savepoints
```

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

## Integration with CI/CD

The SQL executor can be integrated into CI/CD pipelines for automated deployment and management:

### GitHub Actions Integration

```yaml
# Example GitHub Actions workflow
name: Deploy Flink Jobs

on:
  push:
    branches: [main]
    paths: ['sql/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup kubectl
      run: |
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl && sudo mv kubectl /usr/local/bin/
    
    - name: Port forward to Flink cluster  
      run: |
        kubectl port-forward svc/flink-sql-gateway 8083:8083 &
        kubectl port-forward svc/flink-jobmanager 8081:8081 &
        sleep 10  # Wait for port forwarding
    
    - name: Deploy SQL changes
      run: |
        cd flink-studio/sql-executor
        ./run_sql_executor.sh --file ../../sql/deployment.sql --env-file .production.env --enable-database
    
    - name: Verify deployment
      run: |
        cd flink-studio/sql-executor  
        ./run_sql_executor.sh --list-jobs --status-filter RUNNING --json > jobs.json
        echo "Deployed jobs:"
        cat jobs.json | jq '.[] | {job_name, status, start_time}'
```

### GitLab CI Integration

```yaml
# .gitlab-ci.yml example
stages:
  - validate
  - deploy
  - verify

validate-sql:
  stage: validate
  script:
    - cd flink-studio/sql-executor
    - ./run_sql_executor.sh --file $SQL_FILE --dry-run --debug
  variables:
    SQL_FILE: "sql/production-deployment.sql"

deploy-jobs:
  stage: deploy
  script:
    - kubectl port-forward svc/flink-sql-gateway 8083:8083 &
    - kubectl port-forward svc/flink-jobmanager 8081:8081 &
    - sleep 10
    - cd flink-studio/sql-executor
    - ./run_sql_executor.sh --file $SQL_FILE --env-file .production.env --verbose --log-file deployment.log
  artifacts:
    paths:
      - flink-studio/sql-executor/deployment.log
    expire_in: 1 week
  only:
    - main

verify-deployment:
  stage: verify
  script:
    - cd flink-studio/sql-executor
    - ./run_sql_executor.sh --list-jobs --show-all --json | jq '.[] | select(.status != "RUNNING") | {job_name, status}'
```

### Jenkins Pipeline Integration

```groovy
pipeline {
    agent any
    
    environment {
        FLINK_SQL_GATEWAY = 'http://flink-sql-gateway.production.internal:8083'
        FLINK_REST_API = 'http://flink-jobmanager.production.internal:8081'
    }
    
    stages {
        stage('Validate SQL') {
            steps {
                script {
                    sh '''
                        cd flink-studio/sql-executor
                        ./run_sql_executor.sh --file ${SQL_FILE} --dry-run --debug
                    '''
                }
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                script {
                    sh '''
                        cd flink-studio/sql-executor
                        ./run_sql_executor.sh --file ${SQL_FILE} \
                            --sql-gateway-url ${FLINK_SQL_GATEWAY} \
                            --flink-rest-url ${FLINK_REST_API} \
                            --env-file .production.env \
                            --enable-database \
                            --verbose --log-file deployment.log
                    '''
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'flink-studio/sql-executor/deployment.log'
                }
            }
        }
        
        stage('Post-Deployment Verification') {
            steps {
                script {
                    sh '''
                        cd flink-studio/sql-executor
                        ./run_sql_executor.sh --list-jobs --status-filter RUNNING --json > running_jobs.json
                        echo "Currently running jobs:"
                        cat running_jobs.json | jq '.[] | {job_name, status, start_time}'
                    '''
                }
            }
        }
    }
}
```

### Automated Job Management Scripts

#### Production Deployment Script
```bash
#!/bin/bash
# production-deploy.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_EXECUTOR_DIR="${SCRIPT_DIR}/flink-studio/sql-executor"

# Configuration
SQL_FILE="${1:-sql/production-deployment.sql}"
ENV_FILE="${2:-.production.env}"

echo "🚀 Starting production deployment..."

# Validate SQL first
echo "📋 Validating SQL syntax..."
cd "${SQL_EXECUTOR_DIR}"
./run_sql_executor.sh --file "../../${SQL_FILE}" --env-file "${ENV_FILE}" --dry-run --debug

# Pause any existing production jobs
echo "⏸️  Pausing existing production jobs..."
./run_sql_executor.sh --list-pausable --json | jq -r '.[].job_id' | while read job_id; do
    if [[ -n "$job_id" ]]; then
        echo "Pausing job: $job_id"
        ./run_sql_executor.sh --pause-job "$job_id" --savepoint-dir /production/savepoints
    fi
done

# Deploy new version
echo "🔄 Deploying new SQL..."
./run_sql_executor.sh --file "../../${SQL_FILE}" --env-file "${ENV_FILE}" --enable-database --verbose --log-file "deployment-$(date +%Y%m%d-%H%M%S).log"

# Verify deployment
echo "✅ Verifying deployment..."
./run_sql_executor.sh --list-jobs --status-filter RUNNING --json > running_jobs.json
echo "Successfully deployed jobs:"
cat running_jobs.json | jq '.[] | {job_name, status, start_time}'

echo "🎉 Production deployment completed successfully!"
```

#### Job Health Check Script
```bash
#!/bin/bash
# health-check.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_EXECUTOR_DIR="${SCRIPT_DIR}/flink-studio/sql-executor"

cd "${SQL_EXECUTOR_DIR}"

echo "🏥 Flink Cluster Health Check"
echo "============================="

# Check SQL Gateway connectivity
echo "🔍 Checking SQL Gateway connectivity..."
if ./run_sql_executor.sh --sql "SELECT 1" --json > /dev/null 2>&1; then
    echo "✅ SQL Gateway is accessible"
else
    echo "❌ SQL Gateway is not accessible"
    exit 1
fi

# Check running jobs
echo "🔍 Checking running jobs..."
./run_sql_executor.sh --list-jobs --status-filter RUNNING --json > running_jobs.json
RUNNING_COUNT=$(cat running_jobs.json | jq length)
echo "✅ Found ${RUNNING_COUNT} running jobs"

# Check failed jobs
echo "🔍 Checking for failed jobs..."
./run_sql_executor.sh --list-jobs --status-filter FAILED --json > failed_jobs.json
FAILED_COUNT=$(cat failed_jobs.json | jq length)
if [[ $FAILED_COUNT -gt 0 ]]; then
    echo "⚠️  Found ${FAILED_COUNT} failed jobs:"
    cat failed_jobs.json | jq '.[] | {job_name, status, start_time}'
else
    echo "✅ No failed jobs found"
fi

# Check savepoint operations
echo "🔍 Checking active savepoint operations..."
./run_sql_executor.sh --list-active-savepoints --json > active_savepoints.json
ACTIVE_SAVEPOINTS=$(cat active_savepoints.json | jq length)
echo "ℹ️  Found ${ACTIVE_SAVEPOINTS} active savepoint operations"

echo "🎉 Health check completed!"
```

### Docker Integration

For containerized deployments:

```dockerfile
# Dockerfile for SQL Executor
FROM python:3.9-slim

RUN apt-get update && apt-get install -y curl jq && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY flink-studio/sql-executor/ .
RUN pip install -r requirements.txt

ENTRYPOINT ["python", "flink_sql_executor.py"]
```

```bash
# Build and run container
docker build -t flink-sql-executor .
docker run --rm -v $(pwd)/sql:/sql flink-sql-executor --file /sql/deployment.sql --dry-run
```
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
## Example Output and Results

### Successful SQL Execution

```bash
./run_sql_executor.sh --file my_query.sql
```

Expected output:
```
ℹ Setting up Python environment...
ℹ Activating virtual environment...
ℹ Installing/updating dependencies...
✓ Dependencies installed
ℹ Executing Flink SQL Executor...
ℹ️  Checking Flink SQL Gateway connectivity at http://flink-sql-gateway...
✅ Flink SQL Gateway is accessible
2025-01-15 10:30:45,123 - INFO - Executing SQL from file: my_query.sql
2025-01-15 10:30:45,456 - INFO - ✓ SQL Gateway session created: abc123...
2025-01-15 10:30:47,789 - INFO - ✓ my_query.sql completed successfully (2.3s)
✓ SQL execution completed successfully!
```

### Job Listing Output

```bash
./run_sql_executor.sh --list-jobs --json
```

Expected output:
```json
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
  }
]
```

### Error Handling Example

```bash
./run_sql_executor.sh --sql "SELECT * FROM nonexistent_table" --debug
```

Expected output:
```
╭─ SQL Validation Error ────────────────────────────────────────────────────╮
│ SQL validation failed. At line 1, column 15: Object 'nonexistent_table' not found
│
│ This usually means:
│ • Table or column doesn't exist
│ • Data type mismatch
│ • Invalid SQL operation for the context
│
│ Full error details:
│ org.apache.flink.table.api.ValidationException: Object 'nonexistent_table' not found
│     at org.apache.flink.table.planner.calcite.FlinkPlannerImpl...
╰───────────────────────────────────────────────────────────────────────────╯
```

### Dry Run Example

```bash
./run_sql_executor.sh --file setup.sql --dry-run
```

Expected output:
```
ℹ Setting up Python environment...
✅ Flink SQL Gateway is accessible
2025-01-15 10:32:00,123 - INFO - DRY RUN: Would execute 3 SQL statement(s) from setup.sql
2025-01-15 10:32:00,124 - INFO -   Statement 1: CREATE TABLE orders (order_id INT, customer_id INT, amount DOUBLE) WITH (...)
2025-01-15 10:32:00,125 - INFO -   Statement 2: CREATE TABLE daily_totals AS SELECT DATE_FORMAT(order_time, 'yyyy-MM-dd')...
2025-01-15 10:32:00,126 - INFO -   Statement 3: SELECT * FROM daily_totals
2025-01-15 10:32:00,127 - INFO - 🎉 Dry run completed successfully!
```

## Summary

The Flink SQL Executor is a comprehensive tool that provides:

**Core Capabilities:**
- Advanced SQL execution with multi-statement support and session management
- Complete Flink job lifecycle management (list, pause, resume, cancel)
- Comprehensive savepoint operations with persistent tracking
- Environment variable substitution with validation
- Multiple output formats (table, JSON, simple, plain)
- Extensive error handling with debug modes

**Advanced Features:**
- SQLite database integration for job and savepoint persistence
- REST API integration for direct Flink cluster management
- Dry-run mode for safe operation preview
- Configurable retry logic and timeout handling
- CI/CD pipeline integration support
- Comprehensive logging and debugging capabilities

**Production Ready:**
- Robust error handling and recovery mechanisms
- Safe operation modes (dry-run, stop-on-error)
- Session management with automatic cleanup
- Configuration file support with override capabilities
- Extensive validation and safety checks

**Use Cases:**
- **Development**: Test and validate SQL queries with dry-run mode
- **Production Deployment**: Automated job deployment with environment variable support
- **Operations**: Comprehensive job management, monitoring, and maintenance
- **CI/CD Integration**: Automated testing, deployment, and verification
- **Troubleshooting**: Advanced debugging and error analysis capabilities

The tool is designed to be both powerful for advanced users and approachable for everyday SQL execution tasks, making it suitable for development, testing, and production environments.
