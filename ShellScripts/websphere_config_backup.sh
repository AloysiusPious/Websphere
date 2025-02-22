#################################################################################################
#!/bin/bash
# Author: Aloysius Pious
# Version: 1.0
# Date: 2024-08-13
# Description: This script will take websphere config backup and record the activity in logs.
# backup & Log files are maintained with only the latest 10 files being kept.
#################################################################################################
#!/bin/bash
# Define variables
PROFILE_NAME="AppSrv01"
WAS_ROOT="/WASapp/IBM/WebSphere/AppServer"
WAS_PROFILE_DIR="${WAS_ROOT}/profiles/${PROFILE_NAME}"
WAS_BIN_DIR="$WAS_PROFILE_DIR/bin"
BACKUP_DIR="/backup/websphere/${PROFILE_NAME}"
LOG_DIR="$(dirname "$0")/logs"
LOG_FILE="$LOG_DIR/AppSrv01_backup_log_$(date +"%Y%m%d_%H%M%S").log"
BACKUP_FILE="$BACKUP_DIR/AppSrv01_backup_$(date +"%Y%m%d_%H%M%S").zip"
###Backup Files to keep, older file will be deleted
KEEP_ONLY=15

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"
# Log function
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a "$LOG_FILE"
}
# Start logging
log "Starting WebSphere profile backup."
# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"
# Take the backup
log "Running backup command."
"$WAS_BIN_DIR/backupConfig.sh" "$BACKUP_FILE" -nostop > /dev/null
# Check if the backup was successful
if [ $? -eq 0 ]; then
    log "Backup completed successfully. Backup file: $BACKUP_FILE"
else
    log "Backup failed."
    exit 1
fi
# Maintain only the last 10 backup files
log "Cleaning up old backups."
cd "$BACKUP_DIR" || exit 1
BACKUP_COUNT=$(ls -1tr AppSrv01_backup_*.zip | wc -l)
if [ "$BACKUP_COUNT" -gt ${KEEP_ONLY} ]; then
    REMOVE_COUNT=$((BACKUP_COUNT - KEEP_ONLY))
    log "Removing $REMOVE_COUNT old backup(s)."
    ls -1tr AppSrv01_backup_*.zip | head -n "$REMOVE_COUNT" | xargs rm -f
    log "$REMOVE_COUNT old backup(s) removed."
else
    log "No old backups to remove."
fi
# Maintain only the last 10 logs files
log "Cleaning up old logs."
cd "$LOG_DIR" || exit 1
LOG_COUNT=$(ls -1tr AppSrv01_backup_log*.logs | wc -l)
if [ "$LOG_COUNT" -gt ${KEEP_ONLY} ]; then
    REMOVE_COUNT=$((LOG_COUNT - KEEP_ONLY))
    log "Removing $REMOVE_COUNT old log(s)."
    ls -1tr AppSrv01_backup_log*.logs | head -n "$REMOVE_COUNT" | xargs rm -f
    log "$REMOVE_COUNT old log(s) removed."
else
    log "No old logs to remove."
fi
log "WebSphere profile backup script completed."