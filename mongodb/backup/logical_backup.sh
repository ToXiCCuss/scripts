#!/bin/bash

source "$(dirname "$0")/../../linux/notifications.sh"
DISCORD_ERROR_TITLE="MongoDB Logical Backup"

RESTIC_REPOSITORY="rclone:pCloud:/Backups/mongodb_lb"
RESTIC_PASSWORD_FILE="/root/restic"

BACKUP_DIR="/var/backups/mongodb/logical"
DATE=$(date +"%Y-%m-%d_%H-%M")

# ── Backup ───────────────────────────────────────────────────────────────────
echo "[INFO] Creating temporary backup folder..."
mkdir -p "$BACKUP_DIR/$DATE"

echo "[INFO] Starting mongodump..."
CONFIG_FILE="/etc/mongodb-admin.cred"
AUTH_ARGS=""
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    if [ -n "$ADMIN_USER" ] && [ -n "$ADMIN_PASS" ]; then
        AUTH_ARGS="-u $ADMIN_USER -p $ADMIN_PASS --authenticationDatabase admin"
    fi
fi

mongodump $AUTH_ARGS --out "$BACKUP_DIR/$DATE" --quiet

if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to dump databases"
    send_discord_error "Failed to dump databases"
    exit 1
fi

echo "[INFO] Dump created in: $BACKUP_DIR/$DATE"

echo "[INFO] Starting Restic backup..."
if command -v restic >/dev/null 2>&1; then
    restic -r "$RESTIC_REPOSITORY" \
        --password-file "$RESTIC_PASSWORD_FILE" \
        backup "$BACKUP_DIR/$DATE"

    if [ $? -ne 0 ]; then
        echo "[ERROR] Restic backup failed"
        send_discord_error "Restic backup failed"
        exit 1
    fi
else
    echo "[WARN] Restic not found, skipping remote backup."
fi

rm -rf "$BACKUP_DIR/$DATE"
echo "[INFO] Local temporary dumps deleted."

echo "[INFO] Logical backup completed successfully."
