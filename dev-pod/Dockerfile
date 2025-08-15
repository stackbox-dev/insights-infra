FROM ubuntu:22.04

# Set timezone and prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Update and install essential packages
RUN apt-get update && \
    apt-get install -y \
        curl \
        wget \
        git \
        vim \
        nano \
        build-essential \
        software-properties-common \
        gnupg \
        lsb-release \
        ca-certificates \
        screen \
        tmux \
        supervisor \
        tzdata \
        apt-transport-https && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Node.js 22
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install PostgreSQL 16 client
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    apt-get update && \
    apt-get install -y \
        postgresql-client-16 \
        postgresql-client-common \
        pgcli && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install ClickHouse client
RUN apt-get update && \
    apt-get install -y apt-transport-https ca-certificates && \
    wget -O - https://packages.clickhouse.com/rpm/lts/repodata/repomd.xml.key | gpg --dearmor | tee /usr/share/keyrings/clickhouse-keyring.gpg > /dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/clickhouse-keyring.gpg] https://packages.clickhouse.com/deb stable main" | tee /etc/apt/sources.list.d/clickhouse.list && \
    apt-get update && \
    apt-get install -y clickhouse-client && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Java 21 for Kafka tools
RUN mkdir -p /etc/apt/keyrings && \
    wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | tee /etc/apt/keyrings/adoptium.asc && \
    echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list && \
    apt-get update && \
    apt-get install -y temurin-21-jdk && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH

# Install Kafka binaries
RUN KAFKA_VERSION="3.6.1" && \
    SCALA_VERSION="2.13" && \
    wget -q https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz -O /tmp/kafka.tgz && \
    tar -xzf /tmp/kafka.tgz -C /opt/ && \
    mv /opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION} /opt/kafka && \
    ln -s /opt/kafka/bin/* /usr/local/bin/ && \
    rm /tmp/kafka.tgz

# Install kcat (kafkacat)
RUN apt-get update && \
    apt-get install -y kafkacat && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install global npm packages
RUN npm install -g \
    yarn \
    pnpm \
    typescript \
    ts-node \
    nodemon \
    pm2 \
    kafkajs \
    node-rdkafka


# Copy scripts and configurations
COPY scripts/ /usr/local/bin/

# Make scripts executable and create supervisor config directory
RUN chmod +x /usr/local/bin/*.sh && \
    mkdir -p /etc/supervisor/conf.d

# Create workspace directory
RUN mkdir -p /workspace

# Set working directory
WORKDIR /workspace

# Default command
CMD ["/usr/local/bin/start-dev-pod.sh"]