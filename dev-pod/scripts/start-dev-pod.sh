#!/bin/bash
set -e

echo "=== Development Pod Starting ==="
echo "Node.js version: $(node --version)"
echo "npm version: $(npm --version)"
echo "PostgreSQL client version: $(psql --version)"
echo "Java version: $(java --version 2>&1 | head -n 1)"
echo "Kafka tools: $(kafka-topics.sh --version 2>&1 | head -n 1)"
echo "kcat version: $(kafkacat -V 2>&1 | head -1)"
echo ""

echo "=== Quick Start Commands ==="
echo "Connect to PostgreSQL: psql -h <host> -U <user> -d <database>"
echo "List Kafka topics: kafka-topics.sh --bootstrap-server <brokers> --list"
echo ""

# Keep container running
tail -f /dev/null