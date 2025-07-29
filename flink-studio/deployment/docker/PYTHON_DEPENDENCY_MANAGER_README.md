# Flink Dependency Management System

A comprehensive Python-based system for managing Flink Docker image dependencies with compatibility validation and automated updates.

## Architecture

The system consists of:
- **`dependency_manager.py`** - Main Python script with all dependency management logic
- **`manage-deps.sh`** - Bash launcher that sets up Python environment and runs the Python script
- **`dependency-versions.json`** - Central configuration file with all dependency definitions
- **`requirements.txt`** - Python dependencies (requests, packaging)

## Quick Start

1. **Setup the environment** (first time only):
   ```bash
   ./manage-deps.sh setup
   ```

2. **Check current status**:
   ```bash
   ./manage-deps.sh status
   ```

3. **Check for available updates**:
   ```bash
   ./manage-deps.sh check
   ```

4. **Preview updates** (dry run):
   ```bash
   ./manage-deps.sh update --dry-run
   ```

5. **Apply updates**:
   ```bash
   ./manage-deps.sh update
   ```

## Commands

### Environment Management
- `./manage-deps.sh setup` - Set up Python virtual environment and dependencies

### Dependency Operations
- `./manage-deps.sh status` - Show current dependency status and summary
- `./manage-deps.sh check [OPTIONS]` - Check for available updates
- `./manage-deps.sh update [OPTIONS]` - Update dependencies
- `./manage-deps.sh validate` - Validate current versions for Flink compatibility

### Backup & Recovery
- `./manage-deps.sh backup` - Create backup of versions file
- `./manage-deps.sh restore <backup-file>` - Restore from backup

### Reporting
- `./manage-deps.sh report [--output FILE]` - Generate comprehensive compatibility report
- `./manage-deps.sh help` - Show detailed help

## Options

### Global Options
- `--verbose, -v` - Enable verbose output
- `--versions-file FILE` - Specify custom versions file (default: dependency-versions.json)

### Update Command Options
- `--category, -c CAT` - Update specific category only (e.g., kafka, avro, jackson)
- `--dry-run, -n` - Show what would be updated without making changes
- `--force, -f` - Force update even with compatibility warnings
- `--include-prereleases` - Include pre-release versions in update candidates
- `--exclude LIST` - Comma-separated list of dependencies to exclude

### Check Command Options
- `--category, -c CAT` - Check specific category only
- `--include-prereleases` - Include pre-release versions
- `--exclude LIST` - Comma-separated list of dependencies to exclude

## Examples

### Basic Usage
```bash
# Initial setup
./manage-deps.sh setup

# Check status
./manage-deps.sh status

# Check for updates with verbose output
./manage-deps.sh check --verbose

# Preview updates for Kafka dependencies only
./manage-deps.sh update --category kafka --dry-run

# Apply all safe updates
./manage-deps.sh update

# Force update even with compatibility warnings
./manage-deps.sh update --force

# Validate current dependencies
./manage-deps.sh validate

# Generate detailed report
./manage-deps.sh report --output my-report.md
```

### Advanced Usage
```bash
# Update specific category excluding certain dependencies
./manage-deps.sh update --category kafka --exclude kafka-schema-registry-client

# Check for updates including pre-release versions
./manage-deps.sh check --include-prereleases

# Update with custom versions file
./manage-deps.sh update --versions-file custom-versions.json

# Create backup before major updates
./manage-deps.sh backup
./manage-deps.sh update --force
# If issues occur:
./manage-deps.sh restore dependency-versions.json.backup.20241201_143022
```

## Features

### Dependency Management
- **Automatic Updates**: Check Maven repositories for latest versions
- **Compatibility Validation**: Ensure updates are compatible with Flink 2.0.0
- **Category-based Organization**: Group dependencies by type (kafka, avro, jackson, etc.)
- **Selective Updates**: Update specific categories or exclude certain dependencies

### Safety Features
- **Automatic Backups**: Create backups before making changes
- **Dry Run Mode**: Preview changes before applying
- **Compatibility Matrix**: Built-in rules for Flink version compatibility
- **Rollback Support**: Easy restoration from backups

### Reporting & Monitoring
- **Status Dashboard**: Overview of current state and available updates
- **Comprehensive Reports**: Markdown reports with compatibility analysis
- **Verbose Logging**: Detailed output for troubleshooting
- **Color-coded Output**: Easy-to-read terminal output

### Integration
- **Docker Integration**: Works with existing `prepare-image.sh` script
- **Maven Repository Support**: Supports multiple Maven repositories
- **JSON Configuration**: Human-readable configuration format
- **CI/CD Friendly**: Exit codes and automation support

## Configuration

The `dependency-versions.json` file contains:

```json
{
  "metadata": {
    "flink_version": "2.0.0",
    "last_updated": "2024-12-01",
    "description": "Flink 2.0.0 compatible dependencies"
  },
  "dependencies": {
    "kafka": {
      "kafka-clients": {
        "groupId": "org.apache.kafka",
        "artifactId": "kafka-clients",
        "version": "3.8.0",
        "description": "Apache Kafka client library"
      }
    }
  }
}
```

### Metadata Section
- `flink_version`: Target Flink version for compatibility checking
- `last_updated`: Timestamp of last modification
- `description`: Human-readable description

### Dependencies Section
Organized by categories:
- `kafka`: Kafka-related dependencies
- `avro`: Avro serialization dependencies  
- `jackson`: Jackson JSON processing dependencies
- `google`: Google libraries (Guava, gRPC, etc.)
- `scala`: Scala runtime dependencies
- `flink`: Flink-specific dependencies

Each dependency includes:
- `groupId`: Maven group ID
- `artifactId`: Maven artifact ID
- `version`: Current version
- `description`: Human-readable description
- `repository` (optional): Custom Maven repository URL

## Compatibility Matrix

The system includes built-in compatibility rules for Flink 2.0.0:

| Dependency Type | Compatible Range |
|----------------|------------------|
| Kafka | 3.6.0 - 3.8.99 |
| Avro | 1.11.0 - 1.12.99 |
| Jackson | 2.15.0 - 2.17.99 |
| Scala | 2.12.0 - 2.12.99 |
| Google Guava | 30.0 - 35.0 |
| gRPC | 1.50.0 - 1.75.0 |

These rules help prevent incompatible updates that could break Flink functionality.

## Environment Requirements

### Python Requirements
- Python 3.7 or higher
- Virtual environment support (`python3 -m venv`)

### Python Dependencies
- `requests>=2.28.0` - HTTP library for Maven repository access
- `packaging>=21.0` - Version comparison and parsing

### System Requirements
- Bash shell (for launcher script)
- Internet access (for Maven repository queries)
- Write permissions (for backups and updates)

## Troubleshooting

### Environment Issues
```bash
# Check Python version
python3 --version

# Recreate virtual environment
rm -rf .venv
./manage-deps.sh setup

# Manual dependency installation
source .venv/bin/activate
pip install requests packaging
```

### Permission Issues
```bash
# Make scripts executable
chmod +x manage-deps.sh

# Check file permissions
ls -la dependency-versions.json
```

### Network Issues
```bash
# Test Maven repository access
curl -I https://repo1.maven.org/maven2/

# Use verbose mode for debugging
./manage-deps.sh check --verbose
```

### Validation Failures
```bash
# Check current compatibility
./manage-deps.sh validate --verbose

# Generate detailed report
./manage-deps.sh report

# Force updates (use with caution)
./manage-deps.sh update --force
```

## Integration with Docker Build

The system integrates with the existing Docker build process:

1. **`dependency-versions.json`** - Central configuration
2. **`prepare-image.sh`** - Downloads JARs during build
3. **`dependency_manager.py`** - Manages version updates
4. **`manage-deps.sh`** - Provides easy interface

Workflow:
1. Use dependency manager to update versions
2. Docker build reads updated `dependency-versions.json`
3. `prepare-image.sh` downloads the specified JAR versions
4. Docker image contains updated dependencies

## Development

### Adding New Dependencies
1. Edit `dependency-versions.json` manually or use the API:
   ```python
   # In Python script or interactive session
   manager = DependencyManager('dependency-versions.json', logger)
   # Add dependency manipulation code
   ```

2. Update compatibility matrix in `dependency_manager.py` if needed

3. Test the changes:
   ```bash
   ./manage-deps.sh validate
   ./manage-deps.sh check
   ```

### Extending Compatibility Rules
Edit the `CompatibilityMatrix` class in `dependency_manager.py`:

```python
self.rules = {
    'flink-2.0.0': {
        'new-dependency-type': ('min-version', 'max-version'),
    }
}
```

### Custom Repositories
Add repository URLs to dependencies in `dependency-versions.json`:

```json
{
  "custom-dep": {
    "groupId": "com.example",
    "artifactId": "custom-lib",
    "version": "1.0.0",
    "repository": "https://custom-repo.example.com/maven2/",
    "description": "Custom dependency"
  }
}
```

## Migration from Bash System

If migrating from the previous bash-based system:

1. **Backup existing files**:
   ```bash
   cp dependency-versions.json dependency-versions.json.backup
   ```

2. **Set up Python environment**:
   ```bash
   ./manage-deps.sh setup
   ```

3. **Validate current state**:
   ```bash
   ./manage-deps.sh status
   ./manage-deps.sh validate
   ```

4. **Test functionality**:
   ```bash
   ./manage-deps.sh check --dry-run
   ```

The Python system maintains full compatibility with the existing `dependency-versions.json` format and Docker build process.
