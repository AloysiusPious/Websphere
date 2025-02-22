#################################################################################################
#!/bin/bash
# Author: Aloysius Pious
# Version: 1.0
# Date: 2024-08-22
# Description: This script to generate Websphere Heap Dump and Java Core
#################################################################################################
# Check if the script is being run as "wasadm"
if [ `whoami` != "wasadm" ]; then
  echo "Please run this script as \"wasadm\""
  exit 1
fi
# Check if the PID is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <PID>"
    exit 1
fi
# Function to logs messages with timestamps
log_message() {
    local message=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "${DUMP_DIR}/heap_dump_monitor.log"
}
# Function to check if lock file exists
check_lock_file() {
    if [[ -f "$LOCK_FILE" ]]; then
        log_message "Script is running already/ Previous Deployment Failed., Check it Manually."
        log_message "And delete this file ${LOCK_FILE} before run the Script again..."
        exit 1
    else
        touch "$LOCK_FILE"
        log_message "Locking the script to avoid duplicate Execution."
    fi
}
# Variables
PID=$1
DATE_TIME=$(date +"%Y%m%d_%H%M%S")
DATE=$(date +"%Y%m%d")
DUMP="/WASapp/dumps"
DUMP_DIR="${DUMP}/${DATE_TIME}"
LOCK_FILE="${DUMP}/heap_dump_monitor.sh_lock"
# Create a directory for the dumps
mkdir -p "${DUMP_DIR}"
check_lock_file
# Find the profile home directory, node name, and server name associated with the PID
PROFILE_HOME=$(ps -p "$PID" -o args= | grep -oP '[-]Djava\.security\.policy=\K[^ ]+/profiles/[^/]+')
NODE_NAME=$(ps -ef | grep "$PID" | grep -v grep |awk '{ print $(NF-1)}')
SERVER_NAME=$(ps -ef | grep "$PID" | grep -v grep |awk '{ print $(NF)}')
# Ensure the required information was retrieved
if [ -z "$PROFILE_HOME" ] || [ -z "$NODE_NAME" ] || [ -z "$SERVER_NAME" ]; then
    echo "Could not determine profile home directory, node name, or server name for PID $PID"
    exit 1
fi

# Call the Jython script using wsadmin
"${PROFILE_HOME}/bin/wsadmin.sh" -lang jython -f /WASapp/scripts/sys_operations/py/gen_was_dump.py "$NODE_NAME" "$SERVER_NAME" "$DUMP_DIR" 2>&1
# Output the result
mv ${PROFILE_HOME}/heapdump*${DATE}*.phd ${DUMP_DIR}
mv ${PROFILE_HOME}/javacore*${DATE}*.txt ${DUMP_DIR}

# Verify creation
#if [[ -f "${DUMP_DIR}/heapdump*${DATE}*.phd" ]]; then
if ls ${DUMP_DIR}/heapdump*.phd 1> /dev/null 2>&1; then
    echo "Heap dump successfully created: $heap_dump_file"
    echo "Heap dump files are saved in ${DUMP_DIR}"
else
    echo "Heap dump failed."
fi
# Verify creation
#if [[ -f "${DUMP_DIR}/javacore*${DATE}*.txt" ]]; then
if ls ${DUMP_DIR}/javacore*.txt 1> /dev/null 2>&1; then
    echo "Thread dump successfully created: $heap_dump_file"
    echo "Thread dump files are saved in ${DUMP_DIR}"
else
    echo "Thread dump failed."
fi

echo "Cleaned up Older dump directories in ${DUMP}"
find ${DUMP} -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' | sort -n | head -n -10 | cut -d' ' -f2- | xargs -I {} rm -rf {}
rm -f "$LOCK_FILE"
