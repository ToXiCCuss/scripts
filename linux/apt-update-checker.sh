#!/bin/bash

DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1418186339626520660/E7ZJq55YxubJqCRFXDQhNO6Zu9RAe2mwTf37MD28fnVDf25Q8-VfvGCjJAW-fCSxa_9g"
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

    local update_list=""
    local max_display=10
    local count=0

    while IFS= read -r line && [ $count -lt $max_display ]; do
        if [ -n "$line" ]; then
            package_name=$(echo "$line" | awk '{print $1}')
            old_version=$(echo "$line" | awk '{print $2}' | sed 's/\[installed://;s/\]//')
            new_version=$(echo "$line" | awk '{print $3}')

            if grep -q "$package_name" "$TEMP_SECURITY" 2>/dev/null; then
                update_list="${update_list}🔒 **${package_name}**: ${old_version} → ${new_version}\n"
            else
                update_list="${update_list}📦 **${package_name}**: ${old_version} → ${new_version}\n"
            fi
            count=$((count + 1))
        fi
    done < "$TEMP_UPDATES"

    if [ "$TOTAL_UPDATES" -gt $max_display ]; then
        update_list="${update_list}\n... and $(($TOTAL_UPDATES - $max_display)) more updates"
    fi

    curl -s -H "Content-Type: application/json" \
         -X POST \
         -d "{
            \"username\": \"System Updates\",
            \"content\": \"<@${DISCORD_USER_ID}>\",
            \"embeds\": [{
                \"title\": \"${title_emoji} ${hostname}\",
                \"description\": \"${update_list}\",
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
