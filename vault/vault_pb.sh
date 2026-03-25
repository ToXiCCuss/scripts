#!/bin/bash

# Configuration
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1405990393048469554/DsxwaBO38HDaxkwNYwRiePvKvPv35Mxu83OBxC_QWIwYvqUgi4DhbFwz2LuHAr6C9AG8"
DISCORD_ERROR_TITLE="Vault Physical Backup"
DISCORD_USER_ID="261598730027925505"

# Authentifizierung laden
CONFIG_FILE="/etc/vault-backup.cred"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

export VAULT_ADDR=${VAULT_ADDR:-"http://127.0.0.1:8200"}
export VAULT_TOKEN=${VAULT_TOKEN}
# VAULT_TOKEN sollte in CONFIG_FILE definiert sein

RESTIC_REPOSITORY="rclone:pCloud:/Backups/vault_pb"
RESTIC_PASSWORD_FILE="/root/restic"

BACKUP_DIR="/var/backups/vault/physical"
DATE=$(date +"%Y-%m-%d_%H-%M")
SNAPSHOT_FILE="$BACKUP_DIR/vault_snapshot_$DATE.snap"

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

echo "----------------------------------------------------------------------"
echo "[INFO] Starting Vault physical backup process..."

# 1. Ensure Backup Directory exists
mkdir -p "$BACKUP_DIR"

# 2. Create Raft Snapshot
# Note: For Vault backups using Raft, a snapshot is the standard way to create a consistent point-in-time backup.
echo "[INFO] Creating Vault Raft snapshot..."
vault operator raft snapshot save "$SNAPSHOT_FILE"

if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to create Vault snapshot"
    send_discord_error "Failed to create Vault snapshot"
    exit 1
fi

echo "[INFO] Vault snapshot created: $SNAPSHOT_FILE"

# 3. Restic backup
echo "[INFO] Starting Restic backup..."
if command -v restic >/dev/null 2>&1; then
    restic -r "$RESTIC_REPOSITORY" \
        --password-file "$RESTIC_PASSWORD_FILE" \
        backup "$SNAPSHOT_FILE"

    if [ $? -ne 0 ]; then
        echo "[ERROR] Restic backup failed"
        send_discord_error "Restic backup failed"
        exit 1
    fi
else
    echo "[WARN] Restic not found, skipping remote backup."
fi

# 4. Cleanup local copy
rm -f "$SNAPSHOT_FILE"

echo "----------------------------------------------------------------------"
echo "[INFO] Vault physical backup completed successfully."
echo "----------------------------------------------------------------------"
