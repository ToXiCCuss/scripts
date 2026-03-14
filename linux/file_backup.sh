#!/bin/bash

DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1405990393048469554/DsxwaBO38HDaxkwNYwRiePvKvPv35Mxu83OBxC_QWIwYvqUgi4DhbFwz2LuHAr6C9AG8"
DISCORD_ERROR_TITLE="File-Backup"
DISCORD_USER_ID="261598730027925505"

PASSWORD_FILE="/root/restic"
RESTIC_REPO="rclone:pCloud:/Backups/dev"

BACKUP_PATHS=("/var/lib/pterodactyl/volumes")
EXCLUDE_PATHS=("proc/*" "sys/*" "dev/*" "run/*" "tmp/*")

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

if [ ${#BACKUP_PATHS[@]} -eq 0 ]; then
    echo "No backup paths defined. Please configure BACKUP_PATHS in the script."
    send_discord_error "No backup paths defined. Please configure BACKUP_PATHS in the script."
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

restic -r $RESTIC_REPO unlock --password-file $PASSWORD_FILE

BACKUP_COMMAND="restic -r $RESTIC_REPO backup --password-file $PASSWORD_FILE"

for path in "${BACKUP_PATHS[@]}"; do
    BACKUP_COMMAND+=" $path"
done

for exclude in "${EXCLUDE_PATHS[@]}"; do
    BACKUP_COMMAND+=" --exclude $exclude"
done

if eval $BACKUP_COMMAND; then
    echo "Backup completed successfully"
else
    BACKUP_ERROR=$?
    echo "Backup failed with exit code $BACKUP_ERROR"
    send_discord_error "Backup failed with exit code $BACKUP_ERROR"
fi
