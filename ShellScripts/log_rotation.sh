#################################################################################################
#!/bin/bash
# Author: Aloysius Pious
# Version: 1.0
# Date: 2024-08-18
# Description: Log Rotation as per these variable ==> RETENTION_DAYS=7 , #ARCHIVE_RETENTION_DAYS=180  #LOG_CLEANUP_DAYS=7
# Log files self cleaning will be maintained automatically
#################################################################################################
#!/bin/bash
# Variables
LOG_DIR="/Logs/server1"
ARCHIVE_DIR="/archive/websphere"
SCRIPT_LOG_DIR="$(dirname "$0")/logs"
SCRIPT_LOG_FILE="$SCRIPT_LOG_DIR/log_rotation_$(date +"%Y%m%d_%H%M%S").log"
RETENTION_DAYS=3
ARCHIVE_RETENTION_DAYS=30
LOG_CLEANUP_DAYS=7

# Array of logs files with wildcards
LOG_FILES=("$LOG_DIR/SystemOut*.log" "$LOG_DIR/SystemErr*.log")
# Create necessary directories
mkdir -p "$ARCHIVE_DIR"
mkdir -p "$SCRIPT_LOG_DIR"

# Log function
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a "$SCRIPT_LOG_FILE"
}

# Function to compress logs older than RETENTION_DAYS
compress_logs() {
    for LOG_FILE in "${LOG_FILES[@]}"; do
        find "$LOG_DIR" -name "$(basename "$LOG_FILE")" -type f -mtime +$RETENTION_DAYS -exec tar -czf "{}.tar.gz" "{}" \; -exec rm -f "{}" \;
    done
    log "Logs older than $RETENTION_DAYS days compressed."
}

# Function to move compressed files older than RETENTION_DAYS to archive
move_to_archive() {
    find "$LOG_DIR" -name "*.tar.gz" -type f -mtime +$RETENTION_DAYS -exec mv "{}" "$ARCHIVE_DIR/" \;
    log "Compressed logs older than $RETENTION_DAYS days moved to archive."
}

# Function to delete archived files older than ARCHIVE_RETENTION_DAYS
cleanup_archive() {
    find "$ARCHIVE_DIR" -name "*.tar.gz" -type f -mtime +$ARCHIVE_RETENTION_DAYS -exec rm -f "{}" \;
    log "Archived logs older than $ARCHIVE_RETENTION_DAYS days deleted."
}

# Function to clean up script logs older than LOG_CLEANUP_DAYS
cleanup_script_logs() {
    find "$SCRIPT_LOG_DIR" -name "*.log" -type f -mtime +$LOG_CLEANUP_DAYS -exec rm -f "{}" \;
    log "Script logs older than $LOG_CLEANUP_DAYS days deleted."
}

# Run functions
log "Starting log rotation script."
compress_logs
move_to_archive
cleanup_archive
cleanup_script_logs
log "Log rotation script completed."