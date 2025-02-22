#################################################################################################
#!/bin/bash
# Author: Aloysius Pious, email: apious@anb.com.sa
# Version: 1.0
# Date: 2024-10-29
# Description: This script to Monitor the Hung Thread and generate Heap Dump automatically
# Log/ Old Dump files self cleaning will be maintained automatically
#################################################################################################
# Variables
PROFILE_HOME="/WASapp/IBM/WebSphere/AppServer/profiles"
PROFILE_NAME="AppSrv01"
JVM_NAME="server1"
WAS_LOG_DIR="${PROFILE_HOME}/${PROFILE_NAME}/logs/server1/"
LOG_FILE="${WAS_LOG_DIR}/SystemOut.log"   # Replace with the actual path to SystemOut.logs
############################################################################
SYS_OPS_DIR="/WASapp/scripts/sys_operations"
SCRIPT_LOG_DIR="${SYS_OPS_DIR}/logs"
DUMP_DIR="/backup/dumps"
mkdir -p ${DUMP_DIR}
### Required Disk Space in GB
REQ_DISK_SPACE=3
PREVIOUS_ENTRY_FILE="/WASapp/scripts/sys_operations/hung_threads_history.txt"  # File to store previous hung thread entry
# Timestamp for heap dump file
DATE_TIME=$(date +"%Y%m%d_%H%M%S")
HEAP_FILE_DATE=$(date +"%Y%m%d")
LOCK_FILE="${SCRIPT_LOG_DIR}/heap_dump_monitor.sh_lock"
HEAP_DUMP_DIR="${DUMP_DIR}/${DATE_TIME}"  # Directory where heap dump files will be stored
SCRIPT_LOG="${SCRIPT_LOG_DIR}/heap_dump_monitor_$(date +'%Y-%m-%d_%H-%M-%S').log"

# Function to logs messages with timestamps
log_message() {
    touch "$SCRIPT_LOG"
    local message=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> ${SCRIPT_LOG}
}
# Function to check if lock file exists
check_lock_file() {
    if [[ -f "${LOCK_FILE}" ]]; then
        log_message "Script is running already/ Previous execution failed., Check it Manually."
        log_message "And delete this file ${LOCK_FILE} before run the Script again..."
        exit 1
    else
        touch "$LOCK_FILE"
        log_message "Locking the script to avoid duplicate Execution."
    fi
}
# Define a function to compare floating-point numbers
compare() {
    awk "BEGIN {exit !($1 < $2)}"
}
# Function to check available space in /jboss directory on all servers
check_disk_space() {
    log_message " =====>     Checking Disk Space in All the Servers   <====="
    available_space=`df -h $DUMP_DIR | awk 'NR==2 {print $4}' | sed 's/G//g'`
    if compare "$available_space" "$REQ_DISK_SPACE"; then
        log_message "$DUMP_DIR has less than ${REQ_DISK_SPACE}GB, Exiting Script."
        log_message "Clean up required..."
        exit 1
    else
      log_message "$DUMP_DIR has more than : ${REQ_DISK_SPACE}GB."
      log_message "OK."
    fi
}
# Function to generate heap dump
generate_heap_dump() {
    log_message "Executing Jython Script and Generating Heap Dump Files, running in background..."
    # Replace with the WebSphere command to generate heap dump
    "${PROFILE_HOME}/${PROFILE_NAME}/bin/wsadmin.sh" -lang jython -f /WASapp/scripts/sys_operations/py/gen_was_dump.py "$NODE_NAME" "$SERVER_NAME" 2>&1
    log_message "OK."
    # Output the result
    log_message "Moving Heap Dump files to : ${HEAP_DUMP_DIR}, Please wait for 10 Minutes."
    mv ${PROFILE_HOME}/${PROFILE_NAME}/heapdump*${HEAP_FILE_DATE}*.phd ${HEAP_DUMP_DIR}
    sleep 600
    mv ${PROFILE_HOME}/${PROFILE_NAME}/javacore*${HEAP_FILE_DATE}*.txt ${HEAP_DUMP_DIR}
    log_message "OK."
}
cleaup_logs(){
  log_message "Cleaning up Old Script Logs retaining only 10 Latest Files."
  LOGS_COUNT=`ls -1tr ${SCRIPT_LOG_DIR}/heap_dump_monitor_*.logs | wc -l`
  if [ "$LOGS_COUNT" -gt 10 ]; then
      ls -1tr ${SCRIPT_LOG_DIR}/heap_dump_monitor_*.logs | head -n -10 | xargs rm -f
  fi
      log_message "OK."
}
generate_linux_dump(){
  log_message " Generating LinuxPer Dump, running in background..."
  cd ${SYS_OPS_DIR}
  ./linperf.sh ${PID}
  log_message "OK."
  log_message " Moving LinuxPerf dumps to  ${HEAP_DUMP_DIR}..."
  mv linperf_*tar.gz ${HEAP_DUMP_DIR}
  log_message "OK."
}
copy_required_logs(){
  cd ${WAS_LOG_DIR}
  log_message " Copying SystemOut logs to  ${HEAP_DUMP_DIR}..."
  cp -p $(ls -1tr SystemOut* | tail -2) ${HEAP_DUMP_DIR}
  log_message "OK."
  log_message " Copying SystemErr logs to  ${HEAP_DUMP_DIR}..."
  cp -p $(ls -1tr SystemErr* | tail -2) ${HEAP_DUMP_DIR}
  log_message "OK."
  log_message " Copying native_stderr logs to  ${HEAP_DUMP_DIR}..."
  cp -p $(ls -1tr native_stderr* | tail -2) ${HEAP_DUMP_DIR}
  log_message "OK."
  log_message " Copying native_stdout logs to  ${HEAP_DUMP_DIR}..."
  cp -p $(ls -1tr native_stdout* | tail -2) ${HEAP_DUMP_DIR}
  log_message "OK."
  cd ../ffdc
  log_message " Copying FFDC logs to  ${HEAP_DUMP_DIR}..."
  #mkdir -p ${HEAP_DUMP_DIR}/ffdc
  cp -p $(ls -1tr * | tail -8) ${HEAP_DUMP_DIR}/ffdc
  log_message "OK."
}
# Function to generate heap dump
main() {
    PID=$(ps -ef | grep java | grep $JVM_NAME | grep $PROFILE_NAME | grep -v grep |awk -F " " '{print $2}')
    NODE_NAME=$(ps -ef | grep "$PID" | grep -v grep |awk '{ print $(NF-1)}')
    SERVER_NAME=$(ps -ef | grep "$PID" | grep -v grep |awk '{ print $(NF)}')
    # Check if the file to store previous entries exists, if not, create it
    if [ ! -f "$PREVIOUS_ENTRY_FILE" ]; then
        touch "$PREVIOUS_ENTRY_FILE"
    fi
    HEAP_COUNT=$(grep -a "WSVR0605W" "$LOG_FILE" | wc -l)
    if [ "$HEAP_COUNT" -gt 0 ]; then
      # Get the latest hung thread entry from the logs
      latest_entry=$(grep -a "WSVR0605W" "$LOG_FILE" | tail -1 | cut -d'[' -f2 | cut -d']' -f1)
      grep -q "$latest_entry" "$PREVIOUS_ENTRY_FILE"
      # Check if the latest entry is new (not in previous_hung_threads.txt)
      if [ $? -eq 1 ]; then
            [ -n "$latest_entry" ] && echo "$latest_entry" >> "$PREVIOUS_ENTRY_FILE"  # Store the new entry to avoid duplicates
            log_message "New Hung Thread Entry Found at ==> ${latest_entry}"
            check_lock_file
            check_disk_space
            mkdir -p ${HEAP_DUMP_DIR}
            copy_required_logs
            generate_linux_dump &
            generate_heap_dump &
            wait
            #echo "Cleaned up Older dump directories in ${DUMP_DIR}"
            log_message "Cleaning up Heap dump files Retaining only 10 latest files"
            find ${DUMP_DIR} -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' | sort -n | head -n -20 | cut -d' ' -f2- | xargs -I {} rm -rf {}
            log_message "OK."
            log_message "Waiting for few Seconds to remove the Script Lock."
            sleep 10
            log_message "OK."
            cleaup_logs
            rm -f "$LOCK_FILE"
      fi
    fi
}
main