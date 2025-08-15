# Flink Cluster Monitor

A monitoring tool for Apache Flink clusters that tracks job exceptions, health status, and performance metrics.

## Features

- **Exception Monitoring**: Identify jobs with excessive exceptions (configurable threshold)
- **Health Reports**: Comprehensive cluster and job health status
- **Real-time Monitoring**: Continuous monitoring mode with auto-refresh
- **Job Details**: Detailed information about specific jobs including checkpoints
- **JSON Output**: Machine-readable output format for integration with other tools

## Installation

The monitor uses the same virtual environment as the SQL executor. No additional installation is required.

## Usage

### Basic Commands

```bash
# Check for jobs with more than 5 exceptions (default threshold)
./flink-studio/sql-executor/run_monitor.sh --exceptions

# Check for jobs with custom exception threshold
./flink-studio/sql-executor/run_monitor.sh --exceptions --threshold 10

# Show overall cluster health report
./flink-studio/sql-executor/run_monitor.sh --health

# Show details for specific job(s)
./flink-studio/sql-executor/run_monitor.sh --job "pick-drop"

# Continuous monitoring mode (updates every 30 seconds)
./flink-studio/sql-executor/run_monitor.sh --watch

# Continuous monitoring with custom interval
./flink-studio/sql-executor/run_monitor.sh --watch --interval 60

# Output in JSON format (for automation)
./flink-studio/sql-executor/run_monitor.sh --exceptions --json
```

### Combined Reports

Running without any specific flags shows both exception report and health status:

```bash
./flink-studio/sql-executor/run_monitor.sh
```

## Configuration

The monitor uses the same `flink-studio/sql-executor/config.yaml` file as the SQL executor. It reads the Flink cluster URL from:

```yaml
flink_cluster:
  url: "http://flink-session-cluster.flink-studio.api.staging.stackbox.internal"
```

## Output Examples

### Exception Report

```
🔍 Checking for jobs with more than 5 exceptions...

⚠️  Found 1 job(s) with exceptions:

Job: WMS Pick Drop Enrichment
  ID: abc123def456
  State: RUNNING
  Exception Count: 12

  Exception 1 (2024-01-15 10:30:45):
    java.lang.RuntimeException: Failed to serialize row
    at org.apache.flink.formats.avro.AvroRowDataSerializationSchema...

  ... and 9 more exceptions
```

### Health Report

```
📊 Flink Cluster Health Report
================================================================================

🖥️  Cluster Status:
  Flink Version: 2.0.0
  Task Managers: 7
  Total Slots: 21
  Available Slots: 1
  Jobs Running: 9
  Jobs Finished: 4
  Jobs Cancelled: 13
  Jobs Failed: 0

📋 Jobs Overview (26 total):
  ✅ RUNNING: 9
  ❌ CANCELED: 13
  ❌ FINISHED: 4

🏃 Running Jobs:
[Table showing job names, durations, exceptions, restarts, and checkpoint status]
```

### Watch Mode

In watch mode, the screen refreshes automatically showing:
- Current timestamp
- Alert for jobs with exceptions
- Cluster resource utilization
- List of running jobs with status indicators

## Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--config` | Path to configuration file | `flink-studio/sql-executor/config.yaml` |
| `--exceptions` | Check for jobs with exceptions | - |
| `--threshold` | Exception count threshold | 5 |
| `--health` | Show cluster health report | - |
| `--job PATTERN` | Show details for jobs matching pattern | - |
| `--watch` | Enable continuous monitoring | - |
| `--interval` | Watch mode refresh interval (seconds) | 30 |
| `--json` | Output in JSON format | - |

## Integration with CI/CD

The monitor can be integrated into CI/CD pipelines for automated health checks:

```bash
# Check for job failures and exit with error code if found
./flink-studio/sql-executor/run_monitor.sh --exceptions --threshold 0 --json > exceptions.json
if [ $? -ne 0 ]; then
    echo "Jobs with exceptions detected!"
    exit 1
fi
```

## Monitoring Metrics

The monitor tracks the following metrics:

1. **Job Metrics**:
   - Job state (RUNNING, FAILED, CANCELED, etc.)
   - Duration
   - Exception count
   - Restart count
   - Checkpoint status

2. **Cluster Metrics**:
   - Number of Task Managers
   - Total/Available slots
   - Jobs by state
   - Flink version

3. **Checkpoint Metrics**:
   - Total checkpoints
   - Completed/Failed checkpoints
   - Latest checkpoint status
   - State size

## Troubleshooting

### Connection Issues

If the monitor cannot connect to the Flink cluster:

1. Verify the cluster URL in `flink-studio/sql-executor/config.yaml`
2. Ensure you're connected to the correct Kubernetes cluster
3. Check that the Flink service is running:
   ```bash
   kubectl get svc -n flink-studio | grep flink-session-cluster
   ```

### Missing Dependencies

If you encounter import errors, ensure the virtual environment is properly set up:

```bash
# Recreate the virtual environment
rm -rf flink-studio/sql-executor/.venv
./flink-studio/sql-executor/run_monitor.sh --help  # This will recreate the venv
```

## Examples

### Monitor Specific Pipeline

```bash
# Monitor all pick-drop related jobs
./flink-studio/sql-executor/run_monitor.sh --job "pick-drop"

# Monitor enrichment pipelines
./flink-studio/sql-executor/run_monitor.sh --job "enrichment"
```

### Automated Alerting

Create a cron job for regular monitoring:

```bash
# Add to crontab: Check every 5 minutes
*/5 * * * * cd /path/to/insights-infra && ./flink-studio/sql-executor/run_monitor.sh --exceptions --threshold 5 --json >> /var/log/flink-monitor.log 2>&1
```

## Exit Codes

- `0`: Success, no issues found
- `1`: Error occurred or issues detected
- `130`: Interrupted by user (Ctrl+C in watch mode)