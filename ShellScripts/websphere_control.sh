#################################################################################################
# Author: Aloysius Pious
# Script Name : websphere_control.sh
# Version: 1.0
# Date: 2024-08-18
# Description: This script to do STOP/START/RESTART of Websphere
# ##############################################################################################
#!/bin/bash
# Variables
PROFILE_NAME="AppSrv01"
SERVER_NAME="server1"
WSADMIN_USER="wasadm"
LOG_DIR="/WASapp/scripts/logs"
PROFILE_HOME="/WASapp/IBM/WebSphere/AppServer/profiles/${PROFILE_NAME}"
START_SERVER_SCRIPT="$PROFILE_HOME/bin/startServer.sh"
STOP_SERVER_SCRIPT="$PROFILE_HOME/bin/stopServer.sh"
# Ensure the logs directory exists
mkdir -p "$LOG_DIR"
# Function to logs messages with a timestamp
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}
# Check if the script is executed by "wsadmin"
if [ "$USER" != "$WSADMIN_USER" ]; then
  echo "ERROR: Please run this script as \"$WSADMIN_USER\"."
  exit 1
fi
# Function to stop the server
cleanup_logs() {
  # Log Cleanup: Keep only the latest 4 logs files
  cd "$LOG_DIR"
  LOG_COUNT=$(ls -1tr *.logs | wc -l)
  if [ "$LOG_COUNT" -gt 4 ]; then
    ls -1tr *.logs | head -n -4 | xargs rm -f
    log_message "Old Script logs deleted, keeping only the latest 4 Script log files."
  fi
}
# Function to stop the server
stop_server() {
  LOG_FILE="$LOG_DIR/stop_${SERVER_NAME}_$(date '+%Y%m%d%H%M%S').log"
  touch ${LOG_FILE}
  log_message "Attempting to stop WebSphere process..."
  PROCESS_COUNT=$(ps -ef | grep java | grep -v grep |grep "$PROFILE_NAME" |grep "$SERVER_NAME" | wc -l)
  if [ "$PROCESS_COUNT" -gt 0 ]; then
    "$STOP_SERVER_SCRIPT" "$SERVER_NAME" 2>&1 | tee -a "$LOG_FILE"
    sleep 2
    PROCESS_COUNT=$(ps -ef | grep java | grep -v grep | grep "$PROFILE_NAME" |grep "$SERVER_NAME" | wc -l)
	if [ "$PROCESS_COUNT" -gt 0 ]; then
      log_message "ERROR: Failed to stop WebSphere process."
    else
      log_message "WebSphere process stopped successfully."
	  cleanup_logs
      # Clear temporary files
      log_message "Clearing temporary files..."
      rm -rf $PROFILE_HOME/temp/* || exit 1
      log_message "Temp folder cleared."
      sleep 1
      rm -rf $PROFILE_HOME/wstemp/* || exit 1
      log_message "Wstemp folder cleared."
      sleep 1
      rm -rf $PROFILE_HOME/tranlog/* || exit 1
      log_message "Tranlog folder cleared."
      sleep 1
    fi
  else
    log_message "No WebSphere process found to stop."
  fi
}
# Function to start the server
start_server() {
  LOG_FILE="$LOG_DIR/start_${SERVER_NAME}_$(date '+%Y%m%d%H%M%S').log"
  log_message "Attempting to start WebSphere process..."
  PROCESS_COUNT=$(ps -ef | grep java | grep -v grep |grep "$PROFILE_NAME" |grep "$SERVER_NAME" | wc -l)
  if [ "$PROCESS_COUNT" -gt 0 ]; then
    log_message "WebSphere process is already running."
  else
    "$START_SERVER_SCRIPT" "$SERVER_NAME" 2>&1 | tee -a "$LOG_FILE"
    sleep 2
    if pgrep -f "$SERVER_NAME" > /dev/null; then
	  PID=$(ps aux | grep java |grep "$PROFILE_NAME" | grep "$SERVER_NAME" | grep -v grep | awk '{print $2}')
      #PID=$(pgrep -f "$SERVER_NAME")
      START_TIME=$(ps -p $PID -o lstart=)
      log_message "WebSphere process started successfully. PID: $PID, Start Time: $START_TIME"
      #echo "WebSphere process started successfully. PID: $PID, Start Time: $START_TIME"
	  cleanup_logs
    else
      log_message "ERROR: Failed to start WebSphere process."
    fi
  fi
}
# Function to restart the server
restart_server() {
  stop_server
  start_server
}
# Function to display usage
usage() {
  echo "Usage: $0 {STOP|START|RESTART}"
  exit 1
}
# Main script execution
echo " ######################    Websphere Control Script Execution START    ##################### "
case "$1" in
  STOP)
    stop_server
    ;;
  START)
    start_server
    ;;
  RESTART)
    restart_server
    ;;
  *)
    usage
    ;;
esac
echo " ######################    Websphere Control Script Execution END    ##################### "