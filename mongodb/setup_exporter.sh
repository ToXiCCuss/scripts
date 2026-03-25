#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root!"
  exit 1
fi

EXPORTER_USER="mongodb_exporter"
EXPORTER_PASSWORD="${EXPORTER_PASSWORD:-$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 32)}"

echo "Creating MongoDB user for the exporter..."

CONFIG_FILE="/etc/mongodb-admin.cred"
AUTH_ARGS=""
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    if [ -n "$ADMIN_USER" ] && [ -n "$ADMIN_PASS" ]; then
        AUTH_ARGS="-u $ADMIN_USER -p $ADMIN_PASS --authenticationDatabase admin"
    fi
fi

mongosh $AUTH_ARGS --quiet <<EOF
use admin
db.createUser({
  user: "${EXPORTER_USER}",
  pwd: "${EXPORTER_PASSWORD}",
  roles: [
    { role: "clusterMonitor", db: "admin" },
    { role: "read", db: "local" }
  ]
})
EOF

echo "MongoDB Exporter user setup completed!"
echo "User: ${EXPORTER_USER}"
echo "Password: ${EXPORTER_PASSWORD}"
