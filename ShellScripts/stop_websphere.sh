#################################################################################################
#!/bin/bash
# Author: Aloysius Pious
# Version: 1.0
# Date: 2024-08-18
# Description: This script stop Websphere process as defined in variable
#################################################################################################
#!/bin/bash
# Variables
SERVER_NAME="server1"
WSADMIN_USER="wasadm"

LOG_DIR="/WASapp/scripts/logs"
LOG_FILE="$LOG_DIR/stop_"$SERVER_NAME"_$(date '+%Y%m%d%H%M%S').log"
PROFILE_HOME="/WASapp/IBM/WebSphere/AppServer/profiles/AppSrv01"
START_SERVER_SCRIPT="$PROFILE_HOME/bin/stopServer.sh"

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
  log_message "Stopping WebSphere process..."
  # Start WebSphere server
  "$START_SERVER_SCRIPT" "$SERVER_NAME" 2>&1 | tee -a "$LOG_FILE"
else
    log_message "No WebSphere process Found."
  exit 0
  # Check if the process started successfully
  if pgrep -f "$SERVER_NAME" > /dev/null; then
    log_message "ERROR: Failed to Stop WebSphere process."
  else
    log_message "WebSphere process Stopped successfully."
  fi
fi
# Log Cleanup: Keep only the latest 4 logs files
cd "$LOG_DIR"
LOG_COUNT=$(ls -1tr *.logs | wc -l)
if [ "$LOG_COUNT" -gt 4 ]; then
  ls -1tr *.logs | head -n -4 | xargs rm -f
  log_message "Old Script logs deleted, keeping only the latest 4 Script log files."
fi

rm -rf $PROFILE_HOME/temp/* || exit 1
log_message "************ temp folder cleared ********"
sleep 1

rm -rf $PROFILE_HOME/wstemp/* || exit 1
log_message "************ wstemp folder cleared ********"
sleep 1

rm -rf $PROFILE_HOME/tranlog/* || exit 1
log_message "************ tranlog folder cleared ********"
sleep 1

ps -ef|grep java