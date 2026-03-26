#!/bin/bash

source "$(dirname "$0")/../../linux/notifications.sh"
DISCORD_ERROR_TITLE="PostgreSQL Logical Backup"

RESTIC_REPO="rclone:pCloud:/Backups/postgresql_lb"
RESTIC_PASSWORD_FILE="/root/restic"

BACKUP_DIR="/var/backups/postgresql/logical"
DATE=$(date +"%Y-%m-%d_%H-%M")

echo "[INFO] Creating temporary backup folder..."
mkdir -p "$BACKUP_DIR/$DATE"

echo "[INFO] Retrieving database list..."
DBS=$(sudo -u postgres psql -t -c "SELECT datname FROM pg_database WHERE datistemplate = false and datname != 'postgres';")

for DB in $DBS; do
    echo "[INFO] Dumping database: ${DB}"
    sudo -u postgres pg_dump \
      -Fc \
      --clean \
      --if-exists \
      "${DB}" \
      > "$BACKUP_DIR/$DATE/$DB.dump"

    if [ $? -ne 0 ]; then
        echo "[ERROR] Failed to dump database: $DB"
        send_discord_error "Failed to dump database"
        exit 1
    fi
done

echo "[INFO] All dumps created in: $BACKUP_DIR/$DATE"

echo "[INFO] Starting Restic backup..."
restic -r "$RESTIC_REPO" \
    --password-file "$RESTIC_PASSWORD_FILE" \
    backup "$BACKUP_DIR/$DATE"

if [ $? -ne 0 ]; then
    echo "[ERROR] Restic backup failed"
    send_discord_error "Restic backup failed"
    exit 1
fi

rm -rf "$BACKUP_DIR/$DATE"
echo "[INFO] Local temporary dumps deleted."

echo "[INFO] Logical backup completed successfully."
