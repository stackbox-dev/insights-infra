#!/bin/bash
# VS Code tunnel service with auto-restart

TUNNEL_NAME="${VSCODE_TUNNEL_NAME:-dev-pod-$(hostname)}"
LOG_FILE="/workspace/.vscode-tunnel/tunnel.log"
PID_FILE="/workspace/.vscode-tunnel/tunnel.pid"

mkdir -p /workspace/.vscode-tunnel

# Check if tunnel is already running
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE")
  if ps -p "$OLD_PID" > /dev/null 2>&1; then
    echo "VS Code tunnel already running with PID $OLD_PID"
    exit 0
  fi
fi

echo "Starting VS Code tunnel: $TUNNEL_NAME"
echo "Logs will be written to: $LOG_FILE"

# Start tunnel with auto-restart on failure
while true; do
  echo "[$(date)] Starting VS Code tunnel..." >> "$LOG_FILE"
  
  # Run code tunnel and capture PID
  /usr/local/bin/code tunnel \
    --accept-server-license-terms \
    --name "$TUNNEL_NAME" \
    --verbose \
    >> "$LOG_FILE" 2>&1 &
  
  CODE_PID=$!
  echo $CODE_PID > "$PID_FILE"
  
  # Wait for the process to exit
  wait $CODE_PID
  EXIT_CODE=$?
  
  echo "[$(date)] VS Code tunnel exited with code $EXIT_CODE" >> "$LOG_FILE"
  
  # If exit was clean (user initiated), don't restart
  if [ $EXIT_CODE -eq 0 ]; then
    echo "[$(date)] Clean exit detected, not restarting" >> "$LOG_FILE"
    rm -f "$PID_FILE"
    break
  fi
  
  # Wait before restarting
  echo "[$(date)] Restarting in 10 seconds..." >> "$LOG_FILE"
  sleep 10
done