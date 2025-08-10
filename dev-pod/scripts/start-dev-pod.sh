#!/bin/bash
set -e

echo "=== Development Pod Starting ==="
echo "Node.js version: $(node --version)"
echo "npm version: $(npm --version)"
echo "PostgreSQL client version: $(psql --version)"
echo "Java version: $(java --version 2>&1 | head -n 1)"
echo "Kafka tools: $(kafka-topics.sh --version 2>&1 | head -n 1)"
echo "kcat version: $(kafkacat -V 2>&1 | head -1)"
echo "VS Code CLI: $(code --version 2>&1 | head -n 1)"
echo ""

# Create .vscode-tunnel directory before starting supervisor
mkdir -p /workspace/.vscode-tunnel

# Start supervisor for VS Code tunnel
echo "Starting supervisor for VS Code tunnel..."
/usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf &
SUPERVISOR_PID=$!

# Give supervisor time to start
sleep 5

echo "=== VS Code Tunnel Status ==="
echo "Tunnel name: ${VSCODE_TUNNEL_NAME:-dev-pod-$(hostname)}"
echo "Check tunnel status: supervisorctl status vscode-tunnel"
echo "View tunnel logs: tail -f /workspace/.vscode-tunnel/tunnel.log"
echo "Restart tunnel: supervisorctl restart vscode-tunnel"
echo ""
echo "=== Quick Start Commands ==="
echo "Connect to PostgreSQL: psql -h <host> -U <user> -d <database>"
echo "List Kafka topics: kafka-topics.sh --bootstrap-server <brokers> --list"
echo ""

# Keep container running
tail -f /dev/null