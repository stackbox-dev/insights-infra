# Dockerfile for Flink with Google Cloud Storage Support
# Based on official Flink image with GCS connector

ARG FLINK_VERSION=2.0.0
ARG SCALA_VERSION=2.12
ARG JAVA_VERSION=21

FROM flink:${FLINK_VERSION}-scala_${SCALA_VERSION}-java${JAVA_VERSION}

# Set environment variables
ENV FLINK_VERSION=${FLINK_VERSION}
ENV SCALA_VERSION=${SCALA_VERSION}
ENV GCS_CONNECTOR_VERSION=2.2.21

# Switch to root user to install dependencies
USER root

# Install required packages for GCS access
RUN apt-get update && \
    apt-get install -y wget curl ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download and install GCS connector for Hadoop
RUN wget -O /opt/flink/lib/gcs-connector-hadoop3-${GCS_CONNECTOR_VERSION}.jar \
    https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-hadoop3-${GCS_CONNECTOR_VERSION}.jar

# Download Google Cloud client libraries for Application Default Credentials support
RUN wget -O /opt/flink/lib/google-cloud-core-2.38.0.jar \
    https://repo1.maven.org/maven2/com/google/cloud/google-cloud-core/2.38.0/google-cloud-core-2.38.0.jar

RUN wget -O /opt/flink/lib/google-auth-library-oauth2-http-1.23.0.jar \
    https://repo1.maven.org/maven2/com/google/auth/google-auth-library-oauth2-http/1.23.0/google-auth-library-oauth2-http-1.23.0.jar

RUN wget -O /opt/flink/lib/google-auth-library-credentials-1.23.0.jar \
    https://repo1.maven.org/maven2/com/google/auth/google-auth-library-credentials/1.23.0/google-auth-library-credentials-1.23.0.jar

# Create directory for Hadoop configuration
RUN mkdir -p /opt/hadoop/conf

# Copy Hadoop configuration file for GCS
COPY core-site.xml /opt/hadoop/conf/core-site.xml

# Copy GCP authentication verification script
COPY verify-gcp-auth.sh /opt/flink/bin/verify-gcp-auth.sh

# Set Hadoop configuration directory
ENV HADOOP_CONF_DIR=/opt/hadoop/conf
ENV HADOOP_CLASSPATH=/opt/flink/lib/*

# Set Google Cloud environment variables for Application Default Credentials
ENV GOOGLE_APPLICATION_CREDENTIALS=""
ENV GOOGLE_CLOUD_PROJECT=""

# Ensure proper permissions
RUN chown -R flink:flink /opt/hadoop/conf
RUN chmod 644 /opt/hadoop/conf/core-site.xml
RUN chmod +x /opt/flink/bin/verify-gcp-auth.sh

# Switch back to flink user
USER flink

# Set working directory
WORKDIR /opt/flink

# Expose Flink ports
EXPOSE 6123 8081

# Default command
CMD ["help"]
