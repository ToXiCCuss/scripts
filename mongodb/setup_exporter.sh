#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root!"
  exit 1
fi

VERSION="0.40.0"
EXPORTER_USER="mongodb_exporter"
EXPORTER_PASSWORD="${EXPORTER_PASSWORD:-$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 32)}"
LISTEN_ADDRESS="${LISTEN_ADDRESS:-0.0.0.0:9216}"
MONGODB_URI="${MONGODB_URI:-mongodb://127.0.0.1:27017}"

echo "Installing Percona MongoDB Exporter v${VERSION}..."

# Remove old APT package if present
if dpkg -l | grep -q prometheus-mongodb-exporter; then
    echo "Stopping and removing old prometheus-mongodb-exporter..."
    systemctl stop prometheus-mongodb-exporter || true
    systemctl disable prometheus-mongodb-exporter || true
    apt remove -y prometheus-mongodb-exporter || true
    apt purge -y prometheus-mongodb-exporter || true
fi

# Install dependencies
apt update
apt install -y wget tar

# Download and install binary
ARCH=$(uname -m)
case $ARCH in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

FILENAME="mongodb_exporter-${VERSION}.linux-${ARCH}.tar.gz"
URL="https://github.com/percona/mongodb_exporter/releases/download/v${VERSION}/${FILENAME}"

TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"
wget -q "$URL"
tar -xzf "$FILENAME"
# Find the binary in the extracted folder and move it
find . -name "mongodb_exporter" -type f -exec mv {} /usr/local/bin/ \;
chmod +x /usr/local/bin/mongodb_exporter
cd /tmp
rm -rf "$TMP_DIR"

# Ensure prometheus user exists
if ! id "prometheus" &>/dev/null; then
    useradd --no-create-home --shell /bin/false prometheus || true
fi

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

echo "Configuring MongoDB Exporter..."

MONGODB_URI="mongodb://${EXPORTER_USER}:${EXPORTER_PASSWORD}@127.0.0.1:27017/admin?authSource=admin&directConnection=true"
cat > /etc/default/mongodb_exporter <<EOF
MONGODB_URI="${MONGODB_URI}"
LISTEN_ADDRESS="${LISTEN_ADDRESS}"
EOF

echo "Creating systemd service..."
cat > /etc/systemd/system/mongodb_exporter.service <<EOF
[Unit]
Description=Percona MongoDB Exporter
After=network.target

[Service]
User=prometheus
Group=prometheus
EnvironmentFile=/etc/default/mongodb_exporter
ExecStart=/usr/local/bin/mongodb_exporter --mongodb.uri=\${MONGODB_URI} --web.listen-address=\${LISTEN_ADDRESS} --collect-all
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "Starting and enabling mongodb_exporter service..."
systemctl daemon-reload
systemctl enable mongodb_exporter
systemctl restart mongodb_exporter

echo "MongoDB Exporter setup completed!"
echo "User: ${EXPORTER_USER}"
echo "Password: ${EXPORTER_PASSWORD}"
echo "Listening on: ${LISTEN_ADDRESS}"
