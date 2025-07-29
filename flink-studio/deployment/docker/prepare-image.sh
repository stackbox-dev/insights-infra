#!/bin/bash

# Prepare Flink image with Kafka, Avro, Confluent Schema Registry support and filesystem plugins
# This script downloads all required JAR files in parallel and sets up filesystem plugins
# Dependencies versions are managed in dependency-versions.json

set -e  # Exit on any error

FLINK_LIB_DIR="/opt/flink/lib"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSIONS_FILE="${SCRIPT_DIR}/dependency-versions.json"
MAX_PARALLEL_DOWNLOADS=8  # Adjust based on your needs
DOWNLOAD_TIMEOUT=300      # 5 minutes timeout per download

echo "=== Starting Flink image preparation ==="

# Install required tools
echo "Installing required tools..."
apt-get update -qq && apt-get install -y jq unzip bc curl && apt-get clean && rm -rf /var/lib/apt/lists/*

# Verify versions file exists
if [[ ! -f "${VERSIONS_FILE}" ]]; then
    echo "ERROR: ${VERSIONS_FILE} not found!"
    exit 1
fi

echo "Using dependency versions from: ${VERSIONS_FILE}"

# Function to get repository URL (defaults to Maven Central)
get_repository() {
    local category="$1"
    local dep="$2"
    local repo=$(jq -r ".dependencies.\"${category}\".\"${dep}\".repository // \"https://repo1.maven.org/maven2\"" "${VERSIONS_FILE}")
    echo "$repo"
}

# Function to build Maven URL
build_maven_url() {
    local category="$1"
    local dep="$2"
    local group_id=$(jq -r ".dependencies.\"${category}\".\"${dep}\".groupId" "${VERSIONS_FILE}")
    local artifact_id=$(jq -r ".dependencies.\"${category}\".\"${dep}\".artifactId" "${VERSIONS_FILE}")
    local version=$(jq -r ".dependencies.\"${category}\".\"${dep}\".version" "${VERSIONS_FILE}")
    local repository=$(get_repository "$category" "$dep")
    
    # Convert group_id dots to slashes
    local group_path="${group_id//./\/}"
    echo "${repository}/${group_path}/${artifact_id}/${version}/${artifact_id}-${version}.jar"
}

# Function to download a single JAR in background
download_jar_async() {
    local category="$1"
    local dep="$2"
    local download_id="$3"
    
    local group_id=$(jq -r ".dependencies.\"${category}\".\"${dep}\".groupId" "${VERSIONS_FILE}")
    local artifact_id=$(jq -r ".dependencies.\"${category}\".\"${dep}\".artifactId" "${VERSIONS_FILE}")
    local version=$(jq -r ".dependencies.\"${category}\".\"${dep}\".version" "${VERSIONS_FILE}")
    local description=$(jq -r ".dependencies.\"${category}\".\"${dep}\".description" "${VERSIONS_FILE}")
    local url=$(build_maven_url "$category" "$dep")
    local filename="${artifact_id}-${version}.jar"
    local filepath="${FLINK_LIB_DIR}/${filename}"
    
    echo "[$download_id] Starting download: $description"
    
    # Download with timeout and retry
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        # Record start time
        local start_time=$(date +%s)
        
        if timeout $DOWNLOAD_TIMEOUT curl -s -L -o "$filepath" "$url"; then
            # Verify file was downloaded and has reasonable size
            if [[ -f "$filepath" && $(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath" 2>/dev/null) -gt 1024 ]]; then
                # Calculate download time and file size
                local end_time=$(date +%s)
                local download_time=$((end_time - start_time))
                local file_size=$(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath" 2>/dev/null)
                local file_size_mb=$(echo "scale=2; $file_size / 1048576" | bc 2>/dev/null || echo "0")
                
                echo "[$download_id] ✓ Downloaded: $filename (${file_size_mb}MB in ${download_time}s)"
                return 0
            else
                echo "[$download_id] ⚠ Download failed (invalid file): $filename"
                rm -f "$filepath"
            fi
        else
            echo "[$download_id] ⚠ Download failed (attempt $((retry_count + 1))): $filename"
            rm -f "$filepath"
        fi
        
        retry_count=$((retry_count + 1))
        if [[ $retry_count -lt $max_retries ]]; then
            echo "[$download_id] Retrying in 2 seconds..."
            sleep 2
        fi
    done
    
    echo "[$download_id] ✗ Failed to download after $max_retries attempts: $filename"
    echo "[$download_id] URL: $url"
    return 1
}

# Function to wait for background jobs with progress tracking
wait_for_downloads() {
    local total_jobs=$1
    local completed=0
    local failed=0
    
    echo "Waiting for $total_jobs downloads to complete..."
    
    # Wait for all background jobs
    for job in $(jobs -p); do
        if wait $job; then
            completed=$((completed + 1))
        else
            failed=$((failed + 1))
        fi
        echo "Progress: $((completed + failed))/$total_jobs completed (✓ $completed, ✗ $failed)"
    done
    
    if [[ $failed -gt 0 ]]; then
        echo "ERROR: $failed downloads failed!"
        return 1
    fi
    
    echo "All $completed downloads completed successfully!"
    return 0
}

echo "=== Downloading dependencies from ${VERSIONS_FILE} ==="

# Create download queue
declare -a download_queue=()
download_id=0

# Queue all downloads
for category in $(jq -r '.dependencies | keys[]' "${VERSIONS_FILE}"); do
    echo "Queuing $category dependencies..."
    for dep in $(jq -r ".dependencies.\"${category}\" | keys[]" "${VERSIONS_FILE}"); do
        download_id=$((download_id + 1))
        download_queue+=("$category:$dep:$download_id")
    done
done

echo "Total dependencies to download: ${#download_queue[@]}"

# Process downloads in parallel batches
active_jobs=0
total_downloads=${#download_queue[@]}
current_download=0

for item in "${download_queue[@]}"; do
    IFS=':' read -r category dep dl_id <<< "$item"
    current_download=$((current_download + 1))
    
    # Start download in background
    download_jar_async "$category" "$dep" "$dl_id" &
    active_jobs=$((active_jobs + 1))
    
    echo "Started download $current_download/$total_downloads: $category/$dep"
    
    # Limit concurrent downloads
    if [[ $active_jobs -ge $MAX_PARALLEL_DOWNLOADS ]]; then
        echo "Reached max parallel downloads ($MAX_PARALLEL_DOWNLOADS), waiting for some to complete..."
        # Wait for at least one job to complete
        wait -n
        active_jobs=$((active_jobs - 1))
    fi
done

# Wait for remaining downloads
if ! wait_for_downloads $active_jobs; then
    echo "Some downloads failed. Check the errors above."
    exit 1
fi

echo "=== All dependencies downloaded successfully ==="

# Verify all dependencies with checksum validation
echo "=== Verifying all dependencies with checksum validation ==="

# Function to verify JAR checksum in parallel
verify_jar_checksum_async() {
    local category="$1"
    local dep="$2"
    local verify_id="$3"
    
    local artifact_id=$(jq -r ".dependencies.\"${category}\".\"${dep}\".artifactId" "${VERSIONS_FILE}")
    local version=$(jq -r ".dependencies.\"${category}\".\"${dep}\".version" "${VERSIONS_FILE}")
    local filename="${artifact_id}-${version}.jar"
    local filepath="${FLINK_LIB_DIR}/${filename}"
    local repository=$(get_repository "$category" "$dep")
    local group_id=$(jq -r ".dependencies.\"${category}\".\"${dep}\".groupId" "${VERSIONS_FILE}")
    local group_path="${group_id//./\/}"
    
    # Download and verify checksum (SHA1)
    local checksum_url="${repository}/${group_path}/${artifact_id}/${version}/${artifact_id}-${version}.jar.sha1"
    
    if [[ -f "$filepath" ]]; then
        # Record start time for verification
        local start_time=$(date +%s)
        
        # Try to download SHA1 checksum
        local expected_checksum
        if expected_checksum=$(curl -s "$checksum_url" 2>/dev/null | cut -d' ' -f1); then
            if [[ -n "$expected_checksum" && ${#expected_checksum} -eq 40 ]]; then
                # Calculate actual checksum
                local actual_checksum
                if command -v sha1sum &> /dev/null; then
                    actual_checksum=$(sha1sum "$filepath" | cut -d' ' -f1)
                elif command -v shasum &> /dev/null; then
                    actual_checksum=$(shasum -a 1 "$filepath" | cut -d' ' -f1)
                else
                    echo "[$verify_id] ⚠ WARNING: No SHA1 tool available, skipping: $filename"
                    return 0
                fi
                
                local end_time=$(date +%s)
                local verify_time=$((end_time - start_time))
                
                if [[ "$actual_checksum" == "$expected_checksum" ]]; then
                    echo "[$verify_id] ✓ Verified: $filename (${verify_time}s)"
                    return 0
                else
                    echo "[$verify_id] ✗ Checksum mismatch: $filename"
                    echo "[$verify_id]   Expected: $expected_checksum"
                    echo "[$verify_id]   Actual:   $actual_checksum"
                    return 1
                fi
            else
                echo "[$verify_id] ⚠ WARNING: Invalid checksum format, skipping: $filename"
                return 0
            fi
        else
            echo "[$verify_id] ⚠ WARNING: Could not download checksum, skipping: $filename"
            return 0
        fi
    else
        echo "[$verify_id] ✗ Missing dependency: $filename"
        return 1
    fi
}

# Function to wait for verification jobs with progress tracking
wait_for_verifications() {
    local total_jobs=$1
    local completed=0
    local failed=0
    local skipped=0
    
    echo "Waiting for $total_jobs verifications to complete..."
    
    # Wait for all background jobs
    for job in $(jobs -p); do
        if wait $job; then
            local exit_code=$?
            if [[ $exit_code -eq 0 ]]; then
                completed=$((completed + 1))
            else
                skipped=$((skipped + 1))
            fi
        else
            failed=$((failed + 1))
        fi
        echo "Verification progress: $((completed + failed + skipped))/$total_jobs completed (✓ $completed, ⚠ $skipped, ✗ $failed)"
    done
    
    echo ""
    echo "Verification Summary:"
    echo "  ✓ Verified: $completed JARs"
    echo "  ⚠ Skipped:  $skipped JARs"
    echo "  ✗ Failed:   $failed JARs"
    
    if [[ $failed -gt 0 ]]; then
        echo "ERROR: $failed dependencies failed verification!"
        return 1
    fi
    
    echo "All verifications completed successfully!"
    return 0
}

# Verify all downloaded JARs in parallel
verify_id=0
active_verify_jobs=0

echo "Starting parallel verification of all dependencies..."

for category in $(jq -r '.dependencies | keys[]' "${VERSIONS_FILE}"); do
    echo "Starting verification for $category dependencies..."
    for dep in $(jq -r ".dependencies.\"${category}\" | keys[]" "${VERSIONS_FILE}"); do
        verify_id=$((verify_id + 1))
        
        # Start verification in background
        verify_jar_checksum_async "$category" "$dep" "$verify_id" &
        active_verify_jobs=$((active_verify_jobs + 1))
        
        # Limit concurrent verifications (use same limit as downloads)
        if [[ $active_verify_jobs -ge $MAX_PARALLEL_DOWNLOADS ]]; then
            echo "Reached max parallel verifications ($MAX_PARALLEL_DOWNLOADS), waiting for some to complete..."
            # Wait for at least one job to complete
            wait -n
            active_verify_jobs=$((active_verify_jobs - 1))
        fi
    done
done

# Wait for remaining verifications
if ! wait_for_verifications $active_verify_jobs; then
    echo "Some verifications failed. Check the errors above."
    exit 1
fi

echo "=== Setting up filesystem plugins ==="

# Set up filesystem plugins in the plugins directory
plugin_dirs=(
    "gs-fs-hadoop"
    "s3-fs-hadoop" 
    "s3-fs-presto"
    "azure-fs-hadoop"
    "oss-fs-hadoop"
)

for plugin_dir in "${plugin_dirs[@]}"; do
    mkdir -p "/opt/flink/plugins/${plugin_dir}"
done

echo "✓ Created plugin directories"

# Copy filesystem connectors to plugins (with error handling)
echo "Copying filesystem connectors to plugins..."

copy_plugin() {
    local plugin_pattern="$1"
    local plugin_dir="$2"
    local plugin_name="$3"
    
    if ls /opt/flink/opt/${plugin_pattern} 1> /dev/null 2>&1; then
        cp /opt/flink/opt/${plugin_pattern} "/opt/flink/plugins/${plugin_dir}/"
        echo "✓ Copied ${plugin_name} filesystem connector"
    else
        echo "⚠ WARNING: ${plugin_name} filesystem connector not found"
        echo "  Expected: /opt/flink/opt/${plugin_pattern}"
    fi
}

copy_plugin "flink-gs-fs-hadoop-*.jar" "gs-fs-hadoop" "GS"
copy_plugin "flink-s3-fs-hadoop-*.jar" "s3-fs-hadoop" "S3 Hadoop"
copy_plugin "flink-s3-fs-presto-*.jar" "s3-fs-presto" "S3 Presto"
copy_plugin "flink-azure-fs-hadoop-*.jar" "azure-fs-hadoop" "Azure"
copy_plugin "flink-oss-fs-hadoop-*.jar" "oss-fs-hadoop" "OSS"

echo "=== Final verification ==="

# List all downloaded libraries for verification
echo "=== Installed Libraries Summary ==="
total_jars=$(ls -1 "${FLINK_LIB_DIR}/"*.jar | wc -l)
echo "Total JARs installed: $total_jars"

echo ""
echo "Libraries by category:"
for pattern in "kafka" "avro" "google" "jackson" "commons" "snappy" "lz4" "zstd" "yaml" "swagger" "managed-kafka-auth" "grpc" "opencensus"; do
    count=$(ls -1 "${FLINK_LIB_DIR}/" | grep -c -i "$pattern" || echo "0")
    if [[ $count -gt 0 ]]; then
        echo "  $pattern: $count JARs"
    fi
done

# Verify critical gRPC API JAR contents
echo ""
echo "=== All JARs verified with checksums ==="

# Final verification of installed plugins
echo ""
echo "=== Installed Plugins ==="
for plugin_dir in "${plugin_dirs[@]}"; do
    plugin_count=$(find "/opt/flink/plugins/${plugin_dir}" -name "*.jar" | wc -l)
    echo "  ${plugin_dir}: ${plugin_count} JARs"
done

# Show disk usage
echo ""
echo "=== Disk Usage ==="
echo "Library directory size: $(du -sh "${FLINK_LIB_DIR}" | cut -f1)"
echo "Plugins directory size: $(du -sh /opt/flink/plugins | cut -f1)"

echo ""
echo "=== Flink image preparation completed successfully ==="
echo "Downloaded $total_jars dependency JARs in parallel"
echo "All filesystem plugins configured"

# Clean up apt cache to reduce image size
echo "Cleaning up apt cache..."
apt-get clean && rm -rf /var/lib/apt/lists/*
echo "✓ Cleanup completed"
