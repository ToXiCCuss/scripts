#!/bin/bash

source "$(dirname "$0")/../linux/notifications.sh"

PASSWORD_FILE="/root/restic"
RESTIC_REPO="rclone:pCloud:/Backups/docker"

BACKUP_PATHS=("/var/lib/pterodactyl/volumes")
EXCLUDE_PATHS=("proc/*" "sys/*" "dev/*" "run/*" "tmp/*")

if [ ${#BACKUP_PATHS[@]} -eq 0 ]; then
    echo "No backup paths defined. Please configure BACKUP_PATHS in the script."
    send_notification "File-Backup" "No backup paths defined. Please configure BACKUP_PATHS in the script." "error"
    exit 1
fi

export RCLONE_RETRIES=10
export RCLONE_LOW_LEVEL_RETRIES=15
export RCLONE_TIMEOUT=300s
export RCLONE_CHECKERS=4
export RCLONE_TRANSFERS=1
export RCLONE_CHUNK_SIZE=5M
export RCLONE_BUFFER_SIZE=32M
export RCLONE_USE_MMAP=true

echo "----------------------------------------------------------------------"
echo "[INFO] Starting file backup process..."
restic -r $RESTIC_REPO unlock --password-file $PASSWORD_FILE

BACKUP_COMMAND="restic -r $RESTIC_REPO backup --password-file $PASSWORD_FILE"

for path in "${BACKUP_PATHS[@]}"; do
    BACKUP_COMMAND+=" $path"
done

for exclude in "${EXCLUDE_PATHS[@]}"; do
    BACKUP_COMMAND+=" --exclude $exclude"
done

if eval $BACKUP_COMMAND; then
    echo "----------------------------------------------------------------------"
    echo "Backup completed successfully"
    echo "----------------------------------------------------------------------"
    send_notification "File-Backup" "Backup completed successfully" "success"
else
    BACKUP_ERROR=$?
    echo "Backup failed with exit code $BACKUP_ERROR"
    send_notification "File-Backup" "Backup failed with exit code $BACKUP_ERROR" "error"
fi
