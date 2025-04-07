#!/bin/bash
# Variables
REMOTE_IP="x.x.x.x"
SOURCE_PATH="/WASAPP/IBM/Applib/cib"
REMOTE_PATH="/WASAPP/revamp_133_logs"
SNAPSHOT_FILE=".snapshot"
# Check if all variables are set
if [[ -z "$REMOTE_IP" || -z "$SOURCE_PATH" || -z "$REMOTE_PATH" ]]; then
    echo "Error: Please set REMOTE_IP, SOURCE_PATH, and REMOTE_PATH in the script."
    exit 1
fi
# Create an incremental archive
cd ${SOURCE_PATH}
#tar --create --verbose --file - --listed-incremental="$SNAPSHOT_FILE" logs | ssh websphereadmin@anb.net@"$REMOTE_IP" "tar --extract --verbose --directory=$REMOTE_PATH"
# Create an incremental tar archive and extract on the remote host
tar --create --verbose --file - --listed-incremental="$SNAPSHOT_FILE" logs | ssh websphereadmin@anb.net@"$REMOTE_IP" "
    tar --extract --verbose --directory=$REMOTE_PATH &&
    find $REMOTE_PATH -type f -exec chmod 755 {} \; &&
    echo 'Permissions set to 755 for copied files.'"
echo "Incremental sync completed."
