#################################################################################################
#!/bin/bash
# Author: Aloysius Pious, email: apious@anb.com.sa
# Version: 1.0
# Date: 13-JAN-2025
# Description: This script to Monitor websphere Error Codes and write it into a file
# Monitoring tool will see the updated file and send the alerts.
#################################################################################################

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
check_error_codes() {
  log_message "Checking Error Codes in ${LOG_FILE}..."
  touch $OUTPUT_FILE
  # Read the error codes and definitions from the error codes file
  declare -A error_codes
  while IFS=":" read -r code definition; do
      #error_codes["$code"]="$definition"
      #echo $code
      MATCH_COUNT=$(grep -a "${code}" "$LOG_FILE" | wc -l)
      if [ "$MATCH_COUNT" -gt 0 ]; then
        timestamp_entry=$(grep -a "${code}" "$LOG_FILE" | head -1 | cut -d'[' -f2 | cut -d']' -f1)
        latest_entry=$(grep -a "${code}" "$LOG_FILE" | head -1)
        #echo $timestamp_entry
        #echo $latest_entry
        grep -aFq "${latest_entry}" "${OUTPUT_FILE}"
        if [ $? -eq 1 ]; then
          log_message "${latest_entry}"
          [ -n "$latest_entry" ] && echo "ExceptionFound | $latest_entry" >> "${OUTPUT_FILE}"
          #echo $log_entry >> ${OUTPUT_FILE}
        fi
      fi
  done < $ERROR_CODES_FILE
  rm -f "$LOCK_FILE"
}
log_clean_up(){
  ls -1tr ${SCRIPT_LOG_DIR}/websphere_exception_monitor*.logs | head -n -2 | xargs rm -f
  #[ $(stat -c%s "Websphere_Exception_Found.logs") -gt 10485760 ] && > ${OUTPUT_FILE}
  if [ $(stat -c%s "$OUTPUT_FILE") -gt 10485760 ]; then
      echo > "$OUTPUT_FILE"
      log_message "File has been emptied because it was larger than 10MB."
  else
      log_message "$OUTPUT_FILE ==> File size is within the limit, No cleanup needed."
  fi
}
# Define the application name and hostname
APP_NAME="Mubasher"
HOSTNAME=$(hostname)
LOG_FILE="/WASapp/IBM/WebSphere/AppServer/profiles/AppSrv01/logs/server1/SystemOut.log"
#####################
SYS_OPS_DIR="/WASapp/scripts/sys_operations"
SCRIPT_LOG_DIR="${SYS_OPS_DIR}/logs"
LOCK_FILE="${SCRIPT_LOG_DIR}/websphere_exception_monitor.sh_lock"
SCRIPT_LOG="${SCRIPT_LOG_DIR}/websphere_exception_monitor_$(date +'%Y-%m-%d_%H-%M-%S').log"
# Define the files
ERROR_CODES_FILE="${SYS_OPS_DIR}/websphere_error_codes.txt"

OUTPUT_FILE="${SCRIPT_LOG_DIR}/Websphere_Exception_Found.log"
touch $OUTPUT_FILE
chmod 755 ${OUTPUT_FILE}
log_message "Script Execution Start..."
check_lock_file
check_error_codes
log_clean_up
log_message "Done."