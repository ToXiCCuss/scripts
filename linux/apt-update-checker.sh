#!/bin/bash

DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1486676275723763772/V0BLspm8oO0KTYWuwuPgANI7VmXi-GQyHSqS9V6jnM8kzwxcxQsrDy590-1K8FSVDuZW"
DISCORD_USER_ID="261598730027925505"

TEMP_UPDATES="/tmp/apt_updates.txt"
TEMP_SECURITY="/tmp/apt_security.txt"

apt update -qq

apt list --upgradable 2>/dev/null | grep -v "Listing..." > "$TEMP_UPDATES"

grep -i security "$TEMP_UPDATES" > "$TEMP_SECURITY" 2>/dev/null

TOTAL_UPDATES=$(wc -l < "$TEMP_UPDATES")
SECURITY_UPDATES=$(wc -l < "$TEMP_SECURITY")

if [ "$TOTAL_UPDATES" -eq 0 ]; then
    echo "No updates available"
    rm -f "$TEMP_UPDATES" "$TEMP_SECURITY"
    exit 0
fi

send_discord_notification() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local hostname=$(hostname)

    local color=15105570
    local title_emoji="📦"
    if [ "$SECURITY_UPDATES" -gt 0 ]; then
        color=15158332
        title_emoji="🔒"
    fi

    local description="updates available"
    curl -s -H "Content-Type: application/json" \
         -X POST \
         -d "{
            \"username\": \"System Updates\",
            \"content\": \"<@${DISCORD_USER_ID}>\",
            \"embeds\": [{
                \"title\": \"${title_emoji} ${hostname}\",
                \"description\": \"${description}\",
                \"color\": ${color},
                \"fields\": [
                    {
                        \"name\": \"📊 Total\",
                        \"value\": \"${TOTAL_UPDATES} updates\",
                        \"inline\": true
                    },
                    {
                        \"name\": \"🔒 Security\",
                        \"value\": \"${SECURITY_UPDATES} updates\",
                        \"inline\": true
                    },
                    {
                        \"name\": \"🕐 Checked at\",
                        \"value\": \"${timestamp}\",
                        \"inline\": true
                    }
                ]
            }]
         }" \
         "$DISCORD_WEBHOOK_URL"
}

send_discord_notification

rm -f "$TEMP_UPDATES" "$TEMP_SECURITY"
