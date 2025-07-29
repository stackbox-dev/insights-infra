#!/bin/bash

# Prepare Flink image with Kafka, Avro, Confluent Schema Registry support and filesystem plugins
# This script downloads all required JAR files and sets up filesystem plugins

set -e  # Exit on any error

FLINK_LIB_DIR="/opt/flink/lib"

echo "=== Starting Flink image preparation ==="

# Install unzip for JAR verification
echo "Installing unzip for JAR verification..."
apt-get update -qq && apt-get install -y unzip

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

# Core Kafka and Avro connectors - Using universal connector without shading
download_jar "flink-connector-kafka-4.0.0-2.0.jar" \
    "https://repo1.maven.org/maven2/org/apache/flink/flink-connector-kafka/4.0.0-2.0/flink-connector-kafka-4.0.0-2.0.jar" \
    "Flink Kafka Connector (Universal)"

# Also keep the SQL connector but try the universal one first
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

# Confluent Schema Registry support - Compatible with Aiven Kafka
download_jar "flink-avro-confluent-registry-2.0.0.jar" \
    "https://repo1.maven.org/maven2/org/apache/flink/flink-avro-confluent-registry/2.0.0/flink-avro-confluent-registry-2.0.0.jar" \
    "Flink Confluent Avro Registry Connector"

download_jar "kafka-schema-registry-client-7.6.1.jar" \
    "https://packages.confluent.io/maven/io/confluent/kafka-schema-registry-client/7.6.1/kafka-schema-registry-client-7.6.1.jar" \
    "Kafka Schema Registry Client"

# Kafka client libraries - Updated for managed-kafka-auth-login-handler compatibility
# Adding both regular and additional Kafka clients for OAuth compatibility
download_jar "kafka-clients-3.7.1.jar" \
    "https://repo1.maven.org/maven2/org/apache/kafka/kafka-clients/3.7.1/kafka-clients-3.7.1.jar" \
    "Kafka Clients Library"

# Additional Kafka dependencies for unshaded OAuth support
download_jar "kafka_2.13-3.7.1.jar" \
    "https://repo1.maven.org/maven2/org/apache/kafka/kafka_2.13/3.7.1/kafka_2.13-3.7.1.jar" \
    "Kafka Core Library"

# Google libraries (required by schema registry client)
# Using updated Guava version below instead
# download_jar "guava-32.1.2-jre.jar" \
#     "https://repo1.maven.org/maven2/com/google/guava/guava/32.1.2-jre/guava-32.1.2-jre.jar" \
#     "Google Guava Library"

download_jar "jsr305-1.3.9.jar" \
    "https://repo1.maven.org/maven2/com/google/code/findbugs/jsr305/1.3.9/jsr305-1.3.9.jar" \
    "JSR305 Annotations"

# Jackson libraries (required by Avro and Schema Registry) - Updated for managed-kafka-auth-login-handler compatibility
download_jar "jackson-core-2.17.1.jar" \
    "https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-core/2.17.1/jackson-core-2.17.1.jar" \
    "Jackson Core"

download_jar "jackson-databind-2.17.1.jar" \
    "https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-databind/2.17.1/jackson-databind-2.17.1.jar" \
    "Jackson Databind"

download_jar "jackson-annotations-2.17.1.jar" \
    "https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-annotations/2.17.1/jackson-annotations-2.17.1.jar" \
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

# Google Cloud libraries (for GCP integration) - Updated for managed-kafka-auth-login-handler compatibility
download_jar "google-auth-library-credentials-1.23.0.jar" \
    "https://repo1.maven.org/maven2/com/google/auth/google-auth-library-credentials/1.23.0/google-auth-library-credentials-1.23.0.jar" \
    "Google Auth Library Credentials"

download_jar "google-auth-library-oauth2-http-1.23.0.jar" \
    "https://repo1.maven.org/maven2/com/google/auth/google-auth-library-oauth2-http/1.23.0/google-auth-library-oauth2-http-1.23.0.jar" \
    "Google Auth Library OAuth2 HTTP"

download_jar "google-cloud-core-2.8.1.jar" \
    "https://repo1.maven.org/maven2/com/google/cloud/google-cloud-core/2.8.1/google-cloud-core-2.8.1.jar" \
    "Google Cloud Core Library"

# Google Cloud Managed Kafka auth login handler for OAuth authentication
download_jar "managed-kafka-auth-login-handler-1.0.6.jar" \
    "https://repo1.maven.org/maven2/com/google/cloud/hosted/kafka/managed-kafka-auth-login-handler/1.0.6/managed-kafka-auth-login-handler-1.0.6.jar" \
    "Google Cloud Managed Kafka Auth Login Handler"

# Google API Client (required by managed-kafka-auth-login-handler)
download_jar "google-api-client-1.32.1.jar" \
    "https://repo1.maven.org/maven2/com/google/api-client/google-api-client/1.32.1/google-api-client-1.32.1.jar" \
    "Google API Client"

# Google HTTP Client JSON libraries (required by google-api-client for JsonFactory)
download_jar "google-http-client-1.42.3.jar" \
    "https://repo1.maven.org/maven2/com/google/http-client/google-http-client/1.42.3/google-http-client-1.42.3.jar" \
    "Google HTTP Client"

download_jar "google-http-client-jackson2-1.42.3.jar" \
    "https://repo1.maven.org/maven2/com/google/http-client/google-http-client-jackson2/1.42.3/google-http-client-jackson2-1.42.3.jar" \
    "Google HTTP Client Jackson2"

download_jar "google-http-client-gson-1.42.3.jar" \
    "https://repo1.maven.org/maven2/com/google/http-client/google-http-client-gson/1.42.3/google-http-client-gson-1.42.3.jar" \
    "Google HTTP Client Gson"

# Google Gson library (required by Google HTTP Client)
download_jar "gson-2.10.1.jar" \
    "https://repo1.maven.org/maven2/com/google/code/gson/gson/2.10.1/gson-2.10.1.jar" \
    "Google Gson JSON Library"

# Add missing Guava internal dependencies
download_jar "guava-33.2.1-jre.jar" \
    "https://repo1.maven.org/maven2/com/google/guava/guava/33.2.1-jre/guava-33.2.1-jre.jar" \
    "Google Guava Library (Latest)"

download_jar "failureaccess-1.0.2.jar" \
    "https://repo1.maven.org/maven2/com/google/guava/failureaccess/1.0.2/failureaccess-1.0.2.jar" \
    "Google Guava Failure Access"

download_jar "listenablefuture-9999.0-empty-to-avoid-conflict-with-guava.jar" \
    "https://repo1.maven.org/maven2/com/google/guava/listenablefuture/9999.0-empty-to-avoid-conflict-with-guava/listenablefuture-9999.0-empty-to-avoid-conflict-with-guava.jar" \
    "Google Guava ListenableFuture"

# OpenCensus dependencies (required by Google HTTP Client for tracing)
download_jar "opencensus-api-0.31.1.jar" \
    "https://repo1.maven.org/maven2/io/opencensus/opencensus-api/0.31.1/opencensus-api-0.31.1.jar" \
    "OpenCensus API"

download_jar "opencensus-contrib-http-util-0.31.1.jar" \
    "https://repo1.maven.org/maven2/io/opencensus/opencensus-contrib-http-util/0.31.1/opencensus-contrib-http-util-0.31.1.jar" \
    "OpenCensus HTTP Util"

# gRPC dependencies (required by OpenCensus for context management)
download_jar "grpc-api-1.73.0.jar" \
    "https://repo1.maven.org/maven2/io/grpc/grpc-api/1.73.0/grpc-api-1.73.0.jar" \
    "gRPC API (contains io.grpc.Context)"

download_jar "grpc-core-1.73.0.jar" \
    "https://repo1.maven.org/maven2/io/grpc/grpc-core/1.73.0/grpc-core-1.73.0.jar" \
    "gRPC Core"

download_jar "grpc-stub-1.73.0.jar" \
    "https://repo1.maven.org/maven2/io/grpc/grpc-stub/1.73.0/grpc-stub-1.73.0.jar" \
    "gRPC Stub"

download_jar "grpc-protobuf-1.73.0.jar" \
    "https://repo1.maven.org/maven2/io/grpc/grpc-protobuf/1.73.0/grpc-protobuf-1.73.0.jar" \
    "gRPC Protobuf"

download_jar "grpc-protobuf-lite-1.73.0.jar" \
    "https://repo1.maven.org/maven2/io/grpc/grpc-protobuf-lite/1.73.0/grpc-protobuf-lite-1.73.0.jar" \
    "gRPC Protobuf Lite"

# Additional gRPC dependencies for completeness
download_jar "perfmark-api-0.27.0.jar" \
    "https://repo1.maven.org/maven2/io/perfmark/perfmark-api/0.27.0/perfmark-api-0.27.0.jar" \
    "PerfMark API (required by gRPC)"

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
ls -la "${FLINK_LIB_DIR}/" | grep -E "(kafka|avro|google|jsr305|jackson|commons|snappy|lz4|zstd|yaml|swagger|managed-kafka-auth|grpc|opencensus)"

# Verify critical gRPC API JAR contents
echo "=== Verifying gRPC API JAR ==="
if [[ -f "${FLINK_LIB_DIR}/grpc-api-1.73.0.jar" ]]; then
    echo "Checking for io.grpc.Context class in grpc-api JAR:"
    if unzip -l "${FLINK_LIB_DIR}/grpc-api-1.73.0.jar" | grep -q "io/grpc/Context.class"; then
        echo "  ✓ io.grpc.Context class found in grpc-api JAR"
    else
        echo "  ERROR: io.grpc.Context class NOT found in grpc-api JAR!"
        echo "  JAR contents:"
        unzip -l "${FLINK_LIB_DIR}/grpc-api-1.73.0.jar" | head -20
        exit 1
    fi
else
    echo "  ERROR: gRPC API JAR not found!"
    exit 1
fi

# Final verification of installed plugins
echo "=== Installed Plugins ==="
find /opt/flink/plugins -name "*.jar" -exec echo "  {}" \;

echo "=== Flink image preparation completed successfully ==="
