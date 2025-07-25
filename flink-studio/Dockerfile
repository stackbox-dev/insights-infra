# Custom Flink image with Kafka, Avro, and GCP libraries pre-installed
FROM flink:2.0.0-scala_2.12-java21

# Switch to root to install libraries
USER root

# Download and install Kafka connector
RUN wget -O /opt/flink/lib/flink-sql-connector-kafka-4.0.0-2.0.jar \
    https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/4.0.0-2.0/flink-sql-connector-kafka-4.0.0-2.0.jar && \
    test -f /opt/flink/lib/flink-sql-connector-kafka-4.0.0-2.0.jar

# Download and install Avro connector
RUN wget -O /opt/flink/lib/flink-sql-avro-2.0.0.jar \
    https://repo1.maven.org/maven2/org/apache/flink/flink-sql-avro/2.0.0/flink-sql-avro-2.0.0.jar && \
    test -f /opt/flink/lib/flink-sql-avro-2.0.0.jar

# Download and install Google Auth Library for OAuth
RUN wget -O /opt/flink/lib/google-auth-library-oauth2-http-1.19.0.jar \
    https://repo1.maven.org/maven2/com/google/auth/google-auth-library-oauth2-http/1.19.0/google-auth-library-oauth2-http-1.19.0.jar && \
    test -f /opt/flink/lib/google-auth-library-oauth2-http-1.19.0.jar

# Download and install Google Cloud Core library
RUN wget -O /opt/flink/lib/google-cloud-core-2.8.1.jar \
    https://repo1.maven.org/maven2/com/google/cloud/google-cloud-core/2.8.1/google-cloud-core-2.8.1.jar && \
    test -f /opt/flink/lib/google-cloud-core-2.8.1.jar

# Set up filesystem plugins in the plugins directory
RUN mkdir -p /opt/flink/plugins/gs-fs-hadoop && \
    mkdir -p /opt/flink/plugins/s3-fs-hadoop && \
    mkdir -p /opt/flink/plugins/s3-fs-presto && \
    mkdir -p /opt/flink/plugins/azure-fs-hadoop && \
    mkdir -p /opt/flink/plugins/oss-fs-hadoop

# Copy filesystem connectors to plugins (fail if connectors don't exist)
RUN cp /opt/flink/opt/flink-gs-fs-hadoop-*.jar /opt/flink/plugins/gs-fs-hadoop/ && \
    cp /opt/flink/opt/flink-s3-fs-hadoop-*.jar /opt/flink/plugins/s3-fs-hadoop/ && \
    cp /opt/flink/opt/flink-s3-fs-presto-*.jar /opt/flink/plugins/s3-fs-presto/ && \
    cp /opt/flink/opt/flink-azure-fs-hadoop-*.jar /opt/flink/plugins/azure-fs-hadoop/ && \
    cp /opt/flink/opt/flink-oss-fs-hadoop-*.jar /opt/flink/plugins/oss-fs-hadoop/

# List installed libraries for verification
RUN echo "=== Installed Libraries ===" && \
    ls -la /opt/flink/lib/ | grep -E "(kafka|avro|google)" && \
    echo "=== Installed Plugins ===" && \
    find /opt/flink/plugins -name "*.jar" -exec echo "  {}" \; && \
    echo "=== Verification Complete ==="

# Switch back to flink user
# USER flink

# Set working directory
# WORKDIR /opt/flink
