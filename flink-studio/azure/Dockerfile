# Dockerfile for Flink with Azure Blob Storage Support
# Based on official Flink image with Azure connector

ARG FLINK_VERSION=2.0.0
ARG SCALA_VERSION=2.12
ARG JAVA_VERSION=21

FROM flink:${FLINK_VERSION}-scala_${SCALA_VERSION}-java${JAVA_VERSION}

# Set environment variables
ENV FLINK_VERSION=${FLINK_VERSION}
ENV SCALA_VERSION=${SCALA_VERSION}
ENV HADOOP_VERSION=3.4.0
ENV AZURE_STORAGE_VERSION=3.4.0

# Switch to root user to install dependencies
USER root

# Install required packages
RUN apt-get update && \
    apt-get install -y wget curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download and install Azure Storage connector for Hadoop
RUN wget -O /opt/flink/lib/hadoop-azure-${HADOOP_VERSION}.jar \
    https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-azure/${HADOOP_VERSION}/hadoop-azure-${HADOOP_VERSION}.jar

# Download Azure Storage SDK (updated version)
RUN wget -O /opt/flink/lib/azure-storage-12.21.2.jar \
    https://repo1.maven.org/maven2/com/azure/azure-storage-blob/12.21.2/azure-storage-blob-12.21.2.jar

# Download additional Azure dependencies (updated versions)
RUN wget -O /opt/flink/lib/azure-core-1.45.1.jar \
    https://repo1.maven.org/maven2/com/azure/azure-core/1.45.1/azure-core-1.45.1.jar

# Download Jetty dependencies (updated for compatibility)
RUN wget -O /opt/flink/lib/jetty-util-ajax-11.0.18.jar \
    https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-util-ajax/11.0.18/jetty-util-ajax-11.0.18.jar

# Create directory for Hadoop configuration
RUN mkdir -p /opt/hadoop/conf

# Copy Hadoop configuration file for Azure
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
