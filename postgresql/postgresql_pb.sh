#!/bin/bash

STANZA="pg01"
PGBACKREST_REPO="/var/lib/pgbackrest"

RESTIC_REPO="rclone:pCloud:/Backups/postgresql_pb"
RESTIC_PASSWORD_FILE="/var/lib/postgresql/restic"

DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1405990393048469554/DsxwaBO38HDaxkwNYwRiePvKvPv35Mxu83OBxC_QWIwYvqUgi4DhbFwz2LuHAr6C9AG8"
DISCORD_ERROR_TITLE="PostgreSQL Physical Backup"
DISCORD_USER_ID="261598730027925505"

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
                        \"name\": \"🕐 Time\",
                        \"value\": \"$timestamp\",
                        \"inline\": true
                    }
                ]
            }]
         }" \
         "$DISCORD_WEBHOOK_URL"
}

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
