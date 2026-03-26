#!/bin/bash

# Import Benachrichtigungs-Bibliothek
source "$(dirname "$0")/../linux/notifications.sh"
DISCORD_ERROR_TITLE="MariaDB Physical Backup"

RESTIC_REPOSITORY="rclone:pCloud:/Backups/mariadb_lb"
RESTIC_PASSWORD_FILE="/root/restic"

FULL_DIR="/var/backups/mariadb/full"
INC_DIR="/var/backups/mariadb/inc_$(date +%Y-%m-%d_%H-%M)"

echo "----------------------------------------------------------------------"
echo "[INFO] Starting MariaDB physical backup process..."
echo "[INFO] Creating incremental backup..."
mariabackup --backup \
    --target-dir="$INC_DIR" \
    --incremental-basedir="$FULL_DIR"

if [ $? -ne 0 ]; then
    echo "[ERROR] Incremental backup failed"
    send_discord_error "Incremental backup failed"
    exit 1
fi

echo "[INFO] Merging incremental backup into full backup..."
mariabackup --prepare \
    --target-dir="$FULL_DIR" \
    --incremental-dir="$INC_DIR"

if [ $? -ne 0 ]; then
    echo "[ERROR] Merging incremental backup failed"
    send_discord_error "Merging incremental backup failed"
    exit 1
fi

echo "[INFO] Removing temporary incremental directory..."
rm -rf "$INC_DIR"

echo "[INFO] Starting Restic backup to remote repository..."
restic -r "$RESTIC_REPOSITORY" \
    --password-file "$RESTIC_PASSWORD_FILE" \
     backup "$FULL_DIR"

if [ $? -ne 0 ]; then
    echo "[ERROR] Restic backup failed"
    send_discord_error "Restic backup failed"
    exit 1
fi

echo "----------------------------------------------------------------------"
echo "[INFO] Backup completed successfully."
echo "----------------------------------------------------------------------"
