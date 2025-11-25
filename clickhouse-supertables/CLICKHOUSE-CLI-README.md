# ClickHouse CLI Tool

An interactive Node.js CLI tool for managing ClickHouse databases. This tool combines the functionality of `run-sql.sh` and `optimize-tables.sh` into a single, user-friendly interface with a beautiful React-based UI.

## Quick Start

```bash
# Using environment file with --env flag (recommended)
npm run clickhouse -- --env .samadhan-prod.env

# Or without flag
npm run clickhouse .samadhan-prod.env

# Or using direct URL
npm run clickhouse "https://user:pass@host:port/database"
```

## Features

- 📁 **Browse & Execute SQL by Folder**: Browse SQL folders and execute all files in a selected folder
- ✏️ **Execute Inline SQL**: Enter and execute SQL queries directly in the CLI
- ⚡ **Optimize Tables**: Select specific tables or all tables to run OPTIMIZE TABLE FINAL
- 📊 **Show Tables**: Display all tables in the connected database
- 🎨 **Interactive UI**: Beautiful terminal UI powered by Ink and React
- 🔒 **Secure**: Takes ClickHouse URL or env file with embedded credentials (no kubectl/k8s required)
- 🎯 **Flexible Input**: Supports both `--env` flag and direct arguments for consistency with existing tools

## Installation

Dependencies are already included in the project. If needed, run:

```bash
npm install
```

## Usage

The CLI accepts either a ClickHouse HTTP/HTTPS URL or an environment file path.

### Basic Usage

**Option 1: Using Environment File with --env flag**
```bash
npm run clickhouse -- --env <env-file>
```

**Option 2: Using Environment File (direct)**
```bash
npm run clickhouse <env-file>
```

**Option 3: Using URL**
```bash
npm run clickhouse <clickhouse-url>
```

### URL Format

```
https://username:password@hostname:port/database
```

Or with HTTP:

```
http://username:password@hostname:port/database
```

### Examples

**Using --env flag (recommended for consistency with other tools):**
```bash
npm run clickhouse -- --env .sbx-uat.env
npm run clickhouse -- --env .samadhan-prod.env
npm run clickhouse -- --env .huldc-prod.env
```

**Using Environment File (direct):**
```bash
npm run clickhouse .sbx-uat.env
npm run clickhouse .samadhan-prod.env
npm run clickhouse .huldc-prod.env
```

**Using URL:**
```bash
npm run clickhouse "https://avnadmin:AVNS_Cav71ePIZZ8uQdwe2ax@samadhan-clickhouse-hul-samadhan.f.aivencloud.com:25651"
```

**Note**: When using URLs, wrap them in quotes to prevent shell interpretation of special characters.

### Environment File Format

The environment file must contain the following variables:

```bash
CLICKHOUSE_HOSTNAME=your-clickhouse-cluster.aivencloud.com
CLICKHOUSE_HTTP_PORT=25651
CLICKHOUSE_USER=avnadmin
CLICKHOUSE_DATABASE=your_database

# Password - use either of these:
CLICKHOUSE_PASSWORD=your_password
# OR
CLICKHOUSE_ADMIN_PASSWORD=your_password
```

**Note**: The tool accepts either `CLICKHOUSE_PASSWORD` or `CLICKHOUSE_ADMIN_PASSWORD` for the password field. This makes it compatible with both simple configs and existing `.env` files that use the admin password naming convention.

See [.sample.env](.sample.env) for a complete example.

## Features Detail

### 1. Browse & Execute SQL by Folder

- Lists all SQL directories in the project (e.g., `wms-inventory`, `encarta`, `oms`)
- Select a folder to see all SQL files within it
- Execute all files in the selected folder at once
- Files are executed in alphabetical order (use 01-, 02- prefixes for ordering)
- Perfect for running related SQL scripts together

### 2. Execute Inline SQL

- Enter SQL queries directly in the CLI
- Supports any valid ClickHouse SQL (SELECT, INSERT, CREATE, etc.)
- Query results displayed in a dedicated logs viewer
- Full results visible - scroll through your terminal to see everything
- Perfect for quick queries and testing

### 3. Optimize Tables

- Lists all regular tables in the database (excludes views and materialized views)
- Select individual tables, multiple tables, or all tables to optimize
- Runs `OPTIMIZE TABLE <name> FINAL` on selected tables
- Useful for compacting data and improving query performance
- ⚠️ Warning: Can be resource-intensive on large tables

### 4. Show Tables

- Displays all tables in the connected database
- Shows total table count
- Simple list view with table names
- "Back to Main Menu" option to return

## Navigation

- Use **arrow keys** (↑/↓) to navigate menus
- Press **Enter** to select an option
- Press **Ctrl+C** to exit at any time
- After operations complete, a **logs viewer** displays all execution details
- **Scroll up/down** in your terminal to review all logs and query results
- Logs include:
  - File-by-file execution progress
  - Success/failure status for each operation
  - Query results (for inline SQL)
  - Error messages (if any)

## Important Notes

### SQL Execution

- **Multi-statement queries are not supported** by ClickHouse HTTP interface
- Each SQL file is executed individually in sequence
- Files are processed in alphabetical order (use `01-`, `02-` prefixes for ordering)
- **Real-time logs** show progress for each file being executed
- All logs displayed in a dedicated viewer after execution
- If one file fails, execution stops and shows the error in logs
- Scroll through your terminal to review full execution history

### Table Optimization

- Select individual tables or all tables from an interactive list
- Each table is optimized sequentially to avoid resource overload
- **Real-time logs** show progress for each table being optimized
- All logs displayed in a dedicated viewer after completion
- Scroll through your terminal to review optimization history

## Comparison with Bash Scripts

### Old Way (Bash Scripts)

**run-sql.sh:**
```bash
./run-sql.sh --env .sbx-uat.env --pattern "encarta/*.sql"
```
- Required kubectl access to dev-pod
- Needed Kubernetes secret for credentials
- Complex argument parsing
- Required clickhouse-client in pod

**optimize-tables.sh:**
```bash
./optimize-tables.sh --env .sbx-uat.env --filter "^wms_"
```
- Same kubectl/k8s requirements
- Separate script for optimization
- Required dev-pod setup

### New Way (Node.js CLI)

**Using URL:**
```bash
npm run clickhouse "https://user:pass@host:port/db"
```

**Using Environment File:**
```bash
npm run clickhouse .sbx-uat.env
```

**Benefits:**
- ✅ No kubectl required
- ✅ No Kubernetes access needed
- ✅ No dev-pod dependency
- ✅ Direct HTTP/HTTPS connection
- ✅ Single unified interface
- ✅ Beautiful interactive UI with real-time logs viewer
- ✅ Works from any machine with network access
- ✅ Supports both URL and env file inputs
- ✅ Uses existing .env files (compatible with other tools)
- ✅ Full execution history visible in terminal (scroll to review)

## Technical Details

### Architecture

- Built with **Node.js** (ESM modules)
- UI powered by **Ink** (React for CLIs)
- Uses native `fetch` API for HTTP requests
- Async/await for all operations
- No external ClickHouse client required

### SQL File Discovery

Uses `glob` patterns to find SQL files:
- Pattern: `**/*.sql`
- Excludes: `XX-*.sql`, `node_modules/**`
- Sorts files alphabetically for consistent execution order

### Query Execution

- Uses ClickHouse HTTP interface
- Basic authentication with credentials from URL
- Supports query settings (timeouts, etc.)
- Large query support (no buffer limits)

### Error Handling

- Validates URL format
- Checks for TTY (interactive terminal required)
- Displays ClickHouse errors with proper formatting
- Graceful error recovery

## Requirements

- Node.js >= 18.0.0
- Interactive terminal (TTY)
- Network access to ClickHouse server

## Troubleshooting

### "Raw mode is not supported"

This error occurs when running in a non-interactive environment. Solutions:
- Don't run in background (`&`)
- Don't pipe output to other commands
- Run directly in your terminal

### Connection Errors

- Verify the URL format is correct
- Check network connectivity to ClickHouse server
- Ensure credentials are valid
- For HTTPS, the port is usually `8443` or `25651`
- For HTTP, the port is usually `8123`

### No SQL Files Found

- Ensure you're running from the `clickhouse-supertables` directory
- Check that SQL files exist and don't start with `XX-`
- Files must have `.sql` extension

## Security Notes

- ⚠️ Never commit URLs with credentials to git
- ⚠️ Use quotes around URLs to prevent shell history exposure
- ⚠️ Consider using environment variables for production:
  ```bash
  npm run clickhouse "${CLICKHOUSE_URL}"
  ```

## Development

The CLI is a single file: `clickhouse-cli.js`

To modify:
1. Edit `clickhouse-cli.js`
2. Test with `npm run clickhouse <url>`

Key functions:
- `parseClickHouseURL()` - Parses URL into config object
- `executeClickHouseQuery()` - Executes queries via HTTP
- `getSQLFiles()` - Discovers SQL files using glob
- `getTables()` - Fetches table list from ClickHouse
- `App()` - Main React component for UI

## License

MIT
