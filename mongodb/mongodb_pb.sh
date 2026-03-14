#!/bin/bash

# Configuration
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1405990393048469554/DsxwaBO38HDaxkwNYwRiePvKvPv35Mxu83OBxC_QWIwYvqUgi4DhbFwz2LuHAr6C9AG8"
DISCORD_ERROR_TITLE="MongoDB Physical Backup"
DISCORD_USER_ID="261598730027925505"

# Authentifizierung laden
CONFIG_FILE="/etc/mongodb-admin.cred"
AUTH_ARGS=""
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    if [ -n "$ADMIN_USER" ] && [ -n "$ADMIN_PASS" ]; then
        AUTH_ARGS="-u $ADMIN_USER -p $ADMIN_PASS --authenticationDatabase admin"
    fi
fi

RESTIC_REPOSITORY="rclone:pCloud:/Backups/mongodb_pb"
RESTIC_PASSWORD_FILE="/root/restic"

BACKUP_DIR="/var/backups/mongodb/physical"
MONGO_DATA_DIR="/var/lib/mongodb"
DATE=$(date +"%Y-%m-%d_%H-%M")

send_discord_error() {
    local error_message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    curl -s -H "Content-Type: application/json" \
         -X POST \
         -d "{
            \"username\": \"Backups\",
            \"content\": \"<@${DISCORD_USER_ID}>\",
            \"embeds\": [{
                \"title\": \"🚨 $DISCORD_ERROR_TITLE\",
                \"description\": \"**$error_message**\",
                \"color\": 15158332,
                \"fields\": [
                    {
                        \"name\": \"🖥️ Server\",
                        \"value\": \"$(hostname)\",
                        \"inline\": true
                    },
                    {
                        \"name\": \"🕐 Zeit\",
                        \"value\": \"$timestamp\",
                        \"inline\": true
                    }
                ]
            }]
         }" \
         "$DISCORD_WEBHOOK_URL"
}

echo "[INFO] Starting physical backup process..."

# 1. Lock MongoDB to ensure filesystem consistency
# Note: This is a basic approach. For production, filesystem-level snapshots (LVM, EBS) are preferred.
echo "[INFO] Locking MongoDB (fsyncLock)..."
mongosh $AUTH_ARGS --quiet --eval "db.fsyncLock()"

if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to lock MongoDB"
    send_discord_error "Failed to lock MongoDB"
    exit 1
fi

# 2. Copy data files
echo "[INFO] Creating local copy of data files..."
mkdir -p "$BACKUP_DIR/$DATE"
# rsync is used to copy the data files while the DB is locked.
rsync -a "$MONGO_DATA_DIR/" "$BACKUP_DIR/$DATE/"

if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to copy data files"
    send_discord_error "Failed to copy data files"
    # Ensure we try to unlock even if copy failed
    mongosh $AUTH_ARGS --quiet --eval "db.fsyncUnlock()"
    exit 1
fi

# 3. Unlock MongoDB
echo "[INFO] Unlocking MongoDB..."
mongosh $AUTH_ARGS --quiet --eval "db.fsyncUnlock()"

if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to unlock MongoDB"
    send_discord_error "Failed to unlock MongoDB"
    exit 1
fi

# 4. Restic backup
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

# Cleanup local copy
rm -rf "$BACKUP_DIR/$DATE"
echo "[INFO] Physical backup completed successfully."
