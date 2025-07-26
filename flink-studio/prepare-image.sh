#!/bin/bash

# Prepare Flink image with Kafka, Avro, Confluent Schema Registry support and filesystem plugins
# This script downloads all required JAR files and sets up filesystem plugins

set -e  # Exit on any error

FLINK_LIB_DIR="/opt/flink/lib"

echo "=== Starting Flink image preparation ==="

# Function to download and verify JAR
download_jar() {
    local filename="$1"
    local url="$2"
    local description="$3"
    
    echo "Downloading $description..."
    wget -O "${FLINK_LIB_DIR}/${filename}" "$url"
    
    # Verify file was downloaded
    if [[ ! -f "${FLINK_LIB_DIR}/${filename}" ]]; then
        echo "ERROR: Failed to download ${filename}"
        exit 1
    fi
    
    echo "✓ Downloaded ${filename}"
}

echo "=== Downloading dependencies ==="

# Core Kafka and Avro connectors
download_jar "flink-sql-connector-kafka-4.0.0-2.0.jar" \
    "https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/4.0.0-2.0/flink-sql-connector-kafka-4.0.0-2.0.jar" \
    "Flink SQL Kafka Connector"

download_jar "flink-avro-2.0.0.jar" \
    "https://repo1.maven.org/maven2/org/apache/flink/flink-avro/2.0.0/flink-avro-2.0.0.jar" \
    "Flink Avro Connector"

download_jar "flink-sql-avro-2.0.0.jar" \
    "https://repo1.maven.org/maven2/org/apache/flink/flink-sql-avro/2.0.0/flink-sql-avro-2.0.0.jar" \
    "Flink SQL Avro Connector"

download_jar "avro-1.11.4.jar" \
    "https://repo1.maven.org/maven2/org/apache/avro/avro/1.11.4/avro-1.11.4.jar" \
    "Apache Avro Core Library"

# Confluent Schema Registry support
download_jar "flink-avro-confluent-registry-2.0.0.jar" \
    "https://repo1.maven.org/maven2/org/apache/flink/flink-avro-confluent-registry/2.0.0/flink-avro-confluent-registry-2.0.0.jar" \
    "Flink Confluent Avro Registry Connector"

download_jar "kafka-schema-registry-client-7.5.3.jar" \
    "https://packages.confluent.io/maven/io/confluent/kafka-schema-registry-client/7.5.3/kafka-schema-registry-client-7.5.3.jar" \
    "Kafka Schema Registry Client"

# Kafka client libraries
download_jar "kafka-clients-3.4.1.jar" \
    "https://repo1.maven.org/maven2/org/apache/kafka/kafka-clients/3.4.1/kafka-clients-3.4.1.jar" \
    "Kafka Clients Library"

# Google libraries (required by schema registry client)
download_jar "guava-32.1.2-jre.jar" \
    "https://repo1.maven.org/maven2/com/google/guava/guava/32.1.2-jre/guava-32.1.2-jre.jar" \
    "Google Guava Library"

download_jar "jsr305-1.3.9.jar" \
    "https://repo1.maven.org/maven2/com/google/code/findbugs/jsr305/1.3.9/jsr305-1.3.9.jar" \
    "JSR305 Annotations"

# Jackson libraries (required by Avro and Schema Registry)
download_jar "jackson-core-2.15.2.jar" \
    "https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-core/2.15.2/jackson-core-2.15.2.jar" \
    "Jackson Core"

download_jar "jackson-databind-2.15.2.jar" \
    "https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-databind/2.15.2/jackson-databind-2.15.2.jar" \
    "Jackson Databind"

download_jar "jackson-annotations-2.15.2.jar" \
    "https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-annotations/2.15.2/jackson-annotations-2.15.2.jar" \
    "Jackson Annotations"

# Apache Commons (required by Avro and Schema Registry)
download_jar "commons-compress-1.21.jar" \
    "https://repo1.maven.org/maven2/org/apache/commons/commons-compress/1.21/commons-compress-1.21.jar" \
    "Apache Commons Compress"

# Compression libraries (optional but recommended for Kafka clients and Avro)
download_jar "snappy-java-1.1.8.4.jar" \
    "https://repo1.maven.org/maven2/org/xerial/snappy/snappy-java/1.1.8.4/snappy-java-1.1.8.4.jar" \
    "Snappy Java Compression"

download_jar "lz4-java-1.8.0.jar" \
    "https://repo1.maven.org/maven2/org/lz4/lz4-java/1.8.0/lz4-java-1.8.0.jar" \
    "LZ4 Java Compression"

download_jar "zstd-jni-1.5.2-1.jar" \
    "https://repo1.maven.org/maven2/com/github/luben/zstd-jni/1.5.2-1/zstd-jni-1.5.2-1.jar" \
    "ZSTD JNI Compression"

# Additional dependencies (required by schema registry client)
download_jar "snakeyaml-1.33.jar" \
    "https://repo1.maven.org/maven2/org/yaml/snakeyaml/1.33/snakeyaml-1.33.jar" \
    "SnakeYAML"

download_jar "swagger-annotations-2.2.15.jar" \
    "https://repo1.maven.org/maven2/io/swagger/core/v3/swagger-annotations/2.2.15/swagger-annotations-2.2.15.jar" \
    "Swagger Annotations"

# Google Cloud libraries (for GCP integration)
download_jar "google-auth-library-oauth2-http-1.19.0.jar" \
    "https://repo1.maven.org/maven2/com/google/auth/google-auth-library-oauth2-http/1.19.0/google-auth-library-oauth2-http-1.19.0.jar" \
    "Google Auth Library OAuth2 HTTP"

download_jar "google-cloud-core-2.8.1.jar" \
    "https://repo1.maven.org/maven2/com/google/cloud/google-cloud-core/2.8.1/google-cloud-core-2.8.1.jar" \
    "Google Cloud Core Library"

echo "=== All dependencies downloaded successfully ==="

echo "=== Setting up filesystem plugins ==="

# Set up filesystem plugins in the plugins directory
mkdir -p /opt/flink/plugins/gs-fs-hadoop
mkdir -p /opt/flink/plugins/s3-fs-hadoop
mkdir -p /opt/flink/plugins/s3-fs-presto
mkdir -p /opt/flink/plugins/azure-fs-hadoop
mkdir -p /opt/flink/plugins/oss-fs-hadoop

echo "✓ Created plugin directories"

# Copy filesystem connectors to plugins (fail if connectors don't exist)
echo "Copying filesystem connectors to plugins..."

cp /opt/flink/opt/flink-gs-fs-hadoop-*.jar /opt/flink/plugins/gs-fs-hadoop/
echo "✓ Copied GS filesystem connector"

cp /opt/flink/opt/flink-s3-fs-hadoop-*.jar /opt/flink/plugins/s3-fs-hadoop/
echo "✓ Copied S3 Hadoop filesystem connector"

cp /opt/flink/opt/flink-s3-fs-presto-*.jar /opt/flink/plugins/s3-fs-presto/
echo "✓ Copied S3 Presto filesystem connector"

cp /opt/flink/opt/flink-azure-fs-hadoop-*.jar /opt/flink/plugins/azure-fs-hadoop/
echo "✓ Copied Azure filesystem connector"

cp /opt/flink/opt/flink-oss-fs-hadoop-*.jar /opt/flink/plugins/oss-fs-hadoop/
echo "✓ Copied OSS filesystem connector"

echo "=== Verification ==="

# List all downloaded libraries for verification
echo "=== Installed Libraries ===" 
ls -la "${FLINK_LIB_DIR}/" | grep -E "(kafka|avro|google|jsr305|jackson|commons|snappy|lz4|zstd|yaml|swagger)"

# Final verification of installed plugins
echo "=== Installed Plugins ==="
find /opt/flink/plugins -name "*.jar" -exec echo "  {}" \;

echo "=== Flink image preparation completed successfully ==="
