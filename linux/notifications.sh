#!/bin/bash

DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-https://discord.com/api/webhooks/1486656956281389096/Wa82GI8W-EhviU0X1vAjoef2qvDm_s0hsxIGeTTUDc_cq1jdGMgBQEVzM8XnoWUB2OQw}"
DISCORD_USER_ID="${DISCORD_USER_ID:-261598730027925505}"

send_notification() {
    local title="$1"
    local message="$2"
    local type="${3:-error}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local hostname=$(hostname)

    if [ -n "$DISCORD_WEBHOOK_URL" ]; then
        local color=15158332
        local emoji="🚨"
        
        if [ "$type" == "success" ]; then
            color=3066993 # grün
            emoji="✅"
        elif [ "$type" == "info" ]; then
            color=3447003 # blau
            emoji="ℹ️"
        fi

        curl -s -H "Content-Type: application/json" \
             -X POST \
             -d "{
                \"username\": \"Backups\",
                \"content\": \"<@${DISCORD_USER_ID}>\",
                \"embeds\": [{
                    \"title\": \"$emoji $title\",
                    \"description\": \"**$message**\",
                    \"color\": $color,
                    \"fields\": [
                        { \"name\": \"🖥️ Server\", \"value\": \"$hostname\", \"inline\": true },
                        { \"name\": \"🕐 Time\", \"value\": \"$timestamp\", \"inline\": true }
                    ]
                }]
             }" \
             "$DISCORD_WEBHOOK_URL" > /dev/null
    fi
}

send_discord_error() {
    send_notification "${DISCORD_ERROR_TITLE:-Error}" "$1" "error"
}
