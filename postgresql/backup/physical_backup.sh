#!/bin/bash

source "$(dirname "$0")/../../linux/notifications.sh"
DISCORD_ERROR_TITLE="PostgreSQL Physical Backup"
STANZA="pg01"
PGBACKREST_REPO="/var/lib/pgbackrest"

RESTIC_REPO="rclone:pCloud:/Backups/postgresql_pb"
RESTIC_PASSWORD_FILE="/var/lib/postgresql/restic"

echo "----------------------------------------------------------------------"
echo "[INFO] Starting smart PostgreSQL backup process..."

echo "[INFO] Creating differential backup..."
pgbackrest --stanza="$STANZA" backup --type=diff

if [ $? -ne 0 ]; then
    echo "[ERROR] Differential backup failed"
    send_discord_error "Differential backup failed"
    exit 1
fi

echo "[INFO] Differential backup completed successfully"

echo "[INFO] Converting differential to full backup..."

pgbackrest --stanza="$STANZA" backup --type=full

if [ $? -ne 0 ]; then
    echo "[ERROR] Full backup conversion failed"
    send_discord_error "Full backup conversion failed"
    exit 1
fi

echo "[INFO] Cleaning up old backup chain..."
pgbackrest --stanza="$STANZA" expire --retention-full=1

echo "[INFO] Local pgBackRest backup completed successfully"

echo "[INFO] Starting incremental Restic backup..."
restic -r "$RESTIC_REPO" \
    --password-file "$RESTIC_PASSWORD_FILE" \
    backup "$PGBACKREST_REPO"

if [ $? -ne 0 ]; then
    echo "[ERROR] Restic backup failed"
    send_discord_error "Restic backup failed"
    exit 1
fi

echo "----------------------------------------------------------------------"
echo "[INFO] PostgreSQL backup completed successfully!"
echo "----------------------------------------------------------------------"
