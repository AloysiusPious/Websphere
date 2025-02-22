#################################################################################################
#!/bin/bash
# Author: Aloysius Pious
# Version: 1.0
# Date: 2024-08-18
# Description: This script start Websphere process as defined in variable
#################################################################################################
#!/bin/bash
# Variables
SERVER_NAME="server1"
WSADMIN_USER="wasadm"

LOG_DIR="/WASapp/scripts/logs"
LOG_FILE="$LOG_DIR/start_"$SERVER_NAME"_$(date '+%Y%m%d%H%M%S').log"
START_SERVER_SCRIPT="/WASapp/IBM/WebSphere/AppServer/profiles/AppSrv01/bin/startServer.sh"

# Function to logs messages with a timestamp
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}
# Ensure the logs directory exists
mkdir -p "$LOG_DIR"
# Check if the script is executed by "wsadmin"
if [ "$USER" != "$WSADMIN_USER" ]; then
  log_message "ERROR: Please run this script as \"$WSADMIN_USER\"."
  exit 1
fi
# Check if WebSphere process is running
if pgrep -f "$SERVER_NAME" > /dev/null; then
  log_message "WebSphere process is already running."
  exit 0
else
  log_message "Starting WebSphere process..."
  # Start WebSphere server
  "$START_SERVER_SCRIPT" "$SERVER_NAME" 2>&1 | tee -a "$LOG_FILE"
  # Check if the process started successfully
  if pgrep -f "$SERVER_NAME" > /dev/null; then
    log_message "WebSphere process started successfully."
  else
    log_message "ERROR: Failed to start WebSphere process."
  fi
fi
# Log Cleanup: Keep only the latest 4 logs files
cd "$LOG_DIR"
LOG_COUNT=$(ls -1tr *.logs | wc -l)
if [ "$LOG_COUNT" -gt 4 ]; then
  ls -1tr *.logs | head -n -4 | xargs rm -f
  log_message "Old Script logs deleted, keeping only the latest 4 Script log files."
fi