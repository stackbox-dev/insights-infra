# Flink SQL Executor (Node.js/TypeScript)

A modern, TypeScript-based Flink SQL executor with comprehensive job management capabilities.

## Overview

This is a complete rewrite of the Python-based Flink SQL Executor in Node.js/TypeScript, providing:

- **SQL Execution**: Execute SQL from files or inline queries
- **Multi-statement Support**: Run multiple SQL statements in a single session
- **Job Management**: List, cancel, pause, and resume Flink jobs
- **Savepoint Operations**: Create and manage savepoints
- **Database Tracking**: Optional SQLite database for operation history
- **Environment Variables**: Full support for variable substitution
- **Modern CLI**: Built with Commander.js for intuitive command-line interface

## Installation

```bash
# Install dependencies
npm install

# Build the project
npm run build

# Or use during development
npm run dev -- --help
```

## Quick Start

```bash
# Execute SQL from a file
npm start -- --file pipelines/my-pipeline.sql --env-file .sbx-uat.env

# Execute inline SQL
npm start -- --sql "SHOW JOBS" --env-file .sbx-uat.env

# List all running jobs
npm start -- --list-jobs --env-file .sbx-uat.env

# Monitor cluster health
npm run monitor -- --health --env-file .sbx-uat.env
```

## Usage

### Basic SQL Execution

```bash
# Execute SQL from a file
npm start -- --file pipelines/inventory-events.sql --env-file .sbx-uat.env

# Execute inline SQL query
npm start -- --sql "SELECT * FROM orders LIMIT 10" --env-file .sbx-uat.env

# Dry run (preview without executing)
npm start -- --file my-query.sql --dry-run

# Stop on first error
npm start -- --file setup.sql --stop-on-error

# Enable verbose logging
npm start -- --file my-query.sql --verbose --log-file execution.log
```

### Multi-Statement Execution

```bash
# Execute multiple statements (default behavior)
npm start -- --file setup.sql --env-file .sbx-uat.env

# Force single statement mode
npm start -- --file complex-query.sql --single-statement

# Execute multiple inline statements
npm start -- --sql "CREATE TABLE test AS SELECT 1; SELECT * FROM test;"
```

### Job Management

```bash
# List all running jobs
npm start -- --list-jobs --env-file .sbx-uat.env

# List jobs with specific status
npm start -- --list-jobs --status-filter RUNNING --env-file .sbx-uat.env
npm start -- --list-jobs --status-filter FAILED --env-file .sbx-uat.env

# Cancel a specific job
npm start -- --cancel-job <job-id> --env-file .sbx-uat.env

# Cancel all jobs matching a pattern (regex)
npm start -- --cancel-jobs-by-name "WMS.*" --env-file .sbx-uat.env
npm start -- --cancel-jobs-by-name ".*Staging.*" --env-file .sbx-uat.env
npm start -- --cancel-jobs-by-name ".*" --env-file .sbx-uat.env  # Cancel ALL jobs

# Show all jobs (including finished)
npm start -- --list-jobs --show-all --env-file .sbx-uat.env

# Get detailed job information
npm start -- --job-info <job-id> --env-file .sbx-uat.env

# Cancel a job
npm start -- --cancel-job <job-id> --env-file .sbx-uat.env
```

### Savepoint Operations

```bash
# List savepoints (requires database)
npm start -- --list-savepoints --enable-database --env-file .sbx-uat.env

# List with custom limit
npm start -- --list-savepoints --limit 20 --enable-database --env-file .sbx-uat.env

# Show all savepoints
npm start -- --list-savepoints --limit 0 --enable-database --env-file .sbx-uat.env
```

### Monitoring

```bash
# Check cluster health
npm run monitor -- --health --env-file .sbx-uat.env

# Show detailed job information
npm run monitor -- --job-id <job-id> --env-file .sbx-uat.env

# Continuous monitoring
npm run monitor -- --continuous --interval 30 --env-file .sbx-uat.env

# Output in JSON format
npm run monitor -- --health --json --env-file .sbx-uat.env
```

## Environment Configuration

All configuration can be provided via environment variables or `.env` files:

```bash
# Kafka Configuration
KAFKA_ENV=sbx_uat
KAFKA_BOOTSTRAP_SERVERS=kafka-server:22167
SCHEMA_REGISTRY_URL=https://schema-registry:22159
KAFKA_USERNAME=your-username
KAFKA_PASSWORD=your-password

# Flink Configuration
SQL_GATEWAY_URL=http://flink-sql-gateway.flink-studio.svc.cluster.local
FLINK_REST_URL=http://flink-session-cluster.flink-studio.svc.cluster.local

# Job Management
JOB_MANAGEMENT_ENABLE_DATABASE=true
JOB_MANAGEMENT_DATABASE_PATH=flink_jobs.db

# Logging
LOG_LEVEL=INFO
```

## Command-Line Options

### SQL Execution Options

- `-f, --file <path>`: Path to SQL file to execute
- `-s, --sql <query>`: Inline SQL query to execute
- `-e, --env-file <path>`: Environment file for variable substitution (default: .sbx-uat.env)
- `-u, --sql-gateway-url <url>`: Flink SQL Gateway URL
- `--flink-rest-url <url>`: Flink REST API URL
- `-d, --dry-run`: Show what would be executed without running
- `--single-statement`: Treat input as single statement
- `--continue-on-error`: Continue executing remaining statements when one fails (default)
- `--stop-on-error`: Stop execution on first error
- `--format <type>`: Output format: table, simple, plain, json (default: table)
- `--json`: Output results in JSON format
- `-v, --verbose`: Enable verbose logging (DEBUG level)
- `--log-level <level>`: Logging level: DEBUG, INFO, WARNING, ERROR
- `-l, --log-file <path>`: Log file path (optional)
- `--debug`: Enable debug mode with detailed error information

### Job Management Options

- `--list-jobs`: List all jobs from Flink cluster
- `--job-info <id>`: Get detailed information about specific job
- `--status-filter <status>`: Filter jobs by status (RUNNING, FINISHED, CANCELED, FAILED)
- `--cancelled`: Show only cancelled jobs
- `--show-all`: Show jobs of all statuses
- `--cancel-job <id>`: Cancel job gracefully
- `--list-savepoints`: List savepoint history with details
- `--limit <n>`: Maximum savepoints to display (default: 10)
- `--enable-database`: Enable operation database for tracking
- `--disable-database`: Disable operation database
- `--db-path <path>`: Path to SQLite database (default: flink_jobs.db)

### Monitor Options

- `--health`: Check cluster health
- `--job-id <id>`: Monitor specific job by ID
- `--json`: Output in JSON format
- `-c, --continuous`: Continuous monitoring mode
- `-i, --interval <seconds>`: Polling interval in continuous mode (default: 10)

## Development

```bash
# Install dependencies
npm install

# Run in development mode with tsx
npm run dev -- --help

# Build TypeScript
npm run build

# Run built version
npm start -- --help

# Run monitor in dev mode
npm run monitor -- --help

# Lint code
npm run lint

# Format code
npm run format
```

## Project Structure

```
sql-executor/
├── src/
│   ├── lib/
│   │   ├── flink-rest-client.ts      # Flink REST API client
│   │   ├── flink-sql-gateway.ts      # SQL Gateway client
│   │   ├── flink-sql-executor.ts     # Main executor logic
│   │   └── database.ts               # SQLite database layer
│   ├── utils/
│   │   ├── env.ts                    # Environment utilities
│   │   ├── logger.ts                 # Logging utilities
│   │   └── sql-parser.ts             # SQL parsing utilities
│   ├── types.ts                      # TypeScript type definitions
│   ├── index.ts                      # Main CLI entry point
│   └── monitor.ts                    # Monitoring tool
├── dist/                             # Compiled JavaScript (generated)
├── package.json                      # Node.js dependencies
├── tsconfig.json                     # TypeScript configuration
└── README-NODEJS.md                  # This file
```

## Migration from Python Version

The Node.js version maintains feature parity with the Python version:

- ✅ All SQL execution features
- ✅ Multi-statement support with session preservation
- ✅ Job management via REST API
- ✅ Savepoint operations
- ✅ Database tracking (SQLite)
- ✅ Environment variable substitution
- ✅ Monitoring tools
- ✅ Dry-run mode
- ✅ Multiple output formats

### Key Differences

1. **Dependencies**: Uses npm instead of pip
2. **Build Step**: Requires TypeScript compilation
3. **CLI**: Uses Commander.js instead of argparse
4. **Async/Await**: Modern async patterns instead of threading
5. **Type Safety**: Full TypeScript type checking

## Troubleshooting

### Common Issues

**1. Module not found errors**
```bash
npm install
npm run build
```

**2. Permission denied**
```bash
chmod +x dist/index.js dist/monitor.js
```

**3. SQL Gateway not accessible**
- Check Flink cluster is running
- Verify SQL_GATEWAY_URL in env file
- Test connectivity: `curl $SQL_GATEWAY_URL/v1/info`

**4. TypeScript compilation errors**
```bash
npm run clean
npm install
npm run build
```

## Testing

```bash
# Test SQL execution
npm start -- --sql "SELECT 1" --env-file .sbx-uat.env

# Test job listing
npm start -- --list-jobs --env-file .sbx-uat.env

# Test monitoring
npm run monitor -- --health --env-file .sbx-uat.env

# Test dry-run mode
npm start -- --file pipelines/test.sql --dry-run
```

## License

MIT
