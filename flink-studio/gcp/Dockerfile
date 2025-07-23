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

# Install required packages
RUN apt-get update && \
    apt-get install -y wget curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download and install GCS connector for Hadoop
RUN wget -O /opt/flink/lib/gcs-connector-hadoop3-${GCS_CONNECTOR_VERSION}.jar \
    https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-hadoop3-${GCS_CONNECTOR_VERSION}.jar

# Create directory for Hadoop configuration
RUN mkdir -p /opt/hadoop/conf

# Copy Hadoop configuration file for GCS
COPY core-site.xml /opt/hadoop/conf/core-site.xml

# Set Hadoop configuration directory
ENV HADOOP_CONF_DIR=/opt/hadoop/conf
ENV HADOOP_CLASSPATH=/opt/flink/lib/*

# Ensure proper permissions
RUN chown -R flink:flink /opt/hadoop/conf
RUN chmod 644 /opt/hadoop/conf/core-site.xml

# Switch back to flink user
USER flink

# Set working directory
WORKDIR /opt/flink

# Expose Flink ports
EXPOSE 6123 8081

# Default command
CMD ["help"]
