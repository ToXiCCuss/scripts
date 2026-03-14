#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root!"
  exit 1
fi

EXPORTER_USER="mongodb_exporter"
EXPORTER_PASSWORD="${EXPORTER_PASSWORD:-$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 32)}"
LISTEN_ADDRESS="${LISTEN_ADDRESS:-0.0.0.0:9216}"
MONGODB_URI="${MONGODB_URI:-mongodb://localhost:27017}"

echo "Installing prometheus-mongodb-exporter..."
apt update
apt install -y prometheus-mongodb-exporter

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

echo "Configuring prometheus-mongodb-exporter..."

cat > /etc/default/prometheus-mongodb-exporter <<EOF
MONGODB_URI="mongodb://${EXPORTER_USER}:${EXPORTER_PASSWORD}@localhost:27017/admin?authSource=admin"
ARGS="--web.listen-address=${LISTEN_ADDRESS}"
EOF

echo "Starting and enabling prometheus-mongodb-exporter service..."
systemctl restart prometheus-mongodb-exporter
systemctl enable prometheus-mongodb-exporter

echo "MongoDB Exporter setup completed!"
echo "User: ${EXPORTER_USER}"
echo "Password: ${EXPORTER_PASSWORD}"
echo "Listening on: ${LISTEN_ADDRESS}"
