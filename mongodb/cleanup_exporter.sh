#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root!"
  exit 1
fi

EXPORTER_USER="mongodb_exporter"

echo "=========================================="
echo "MongoDB Exporter Cleanup"
echo "=========================================="
echo ""

echo "Stopping and removing services..."
systemctl stop mongodb_exporter || true
systemctl disable mongodb_exporter || true
systemctl stop prometheus-mongodb-exporter || true
systemctl disable prometheus-mongodb-exporter || true

echo "Removing binaries and packages..."
rm -f /usr/local/bin/mongodb_exporter
if dpkg -l | grep -q prometheus-mongodb-exporter; then
    apt remove -y prometheus-mongodb-exporter
    apt purge -y prometheus-mongodb-exporter
fi

echo "Removing configuration and service files..."
rm -f /etc/default/mongodb_exporter
rm -f /etc/default/prometheus-mongodb-exporter
rm -f /etc/systemd/system/mongodb_exporter.service
systemctl daemon-reload

echo "Removing MongoDB user '${EXPORTER_USER}' from 'admin' database..."

CONFIG_FILE="/etc/mongodb-admin.cred"
AUTH_ARGS=""
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    if [ -n "$ADMIN_USER" ] && [ -n "$ADMIN_PASS" ]; then
        AUTH_ARGS="-u $ADMIN_USER -p $ADMIN_PASS --authenticationDatabase admin"
    fi
fi

# Run MongoDB command to drop the user
# We ignore errors in case the user was already removed or mongosh is not available
if command -v mongosh &> /dev/null; then
    if mongosh $AUTH_ARGS --quiet <<EOF
use admin
db.dropUser("${EXPORTER_USER}")
EOF
    then
        echo "User '${EXPORTER_USER}' deleted successfully."
    else
        echo "Note: User '${EXPORTER_USER}' could not be deleted or did not exist (this is often normal during cleanup)."
    fi
else
    echo "mongosh not found. Could not remove MongoDB user automatically."
fi

echo ""
echo "=========================================="
echo "Cleanup Complete"
echo "=========================================="
echo "The following items have been removed:"
echo "  - mongodb_exporter service and binary (Percona version)"
echo "  - prometheus-mongodb-exporter package (legacy version, if present)"
echo "  - Configuration and service files"
echo "  - MongoDB user '${EXPORTER_USER}'"
echo "=========================================="
