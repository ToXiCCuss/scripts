#!/bin/bash

DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1405990393048469554/DsxwaBO38HDaxkwNYwRiePvKvPv35Mxu83OBxC_QWIwYvqUgi4DhbFwz2LuHAr6C9AG8"
DISCORD_ERROR_TITLE="PostgreSQL Logical Backup"
DISCORD_USER_ID="261598730027925505"

RESTIC_REPO="rclone:pCloud:/Backups/postgresql_lb"
RESTIC_PASSWORD_FILE="/root/restic"

BACKUP_DIR="/var/backups/postgresql/logical"
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
                        \"name\": \"🕐 Time\",
                        \"value\": \"$timestamp\",
                        \"inline\": true
                    }
                ]
            }]
         }" \
         "$DISCORD_WEBHOOK_URL"
}

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
