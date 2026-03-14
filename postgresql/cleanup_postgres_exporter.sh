#!/bin/bash
set -e

echo "=========================================="
echo "PostgreSQL Exporter Cleanup"
echo "=========================================="
echo ""

# Variables
EXPORTER_USER="postgres_exporter"
EXPORTER_DIR="/opt/postgres_exporter"
CONFIG_FILE="/etc/postgres_exporter/postgres_exporter.yml"
SERVICE_FILE="/etc/systemd/system/postgres_exporter.service"

# Stop and disable service
echo "Stopping postgres_exporter service..."
systemctl stop postgres_exporter || true
systemctl disable postgres_exporter || true

# Remove service file
echo "Removing systemd service file..."
rm -f $SERVICE_FILE
systemctl daemon-reload

# Remove exporter directory
echo "Removing exporter directory..."
rm -rf $EXPORTER_DIR

# Remove configuration files
echo "Removing configuration files..."
rm -rf /etc/postgres_exporter

# Drop PostgreSQL user
echo "Dropping PostgreSQL user '$EXPORTER_USER'..."
sudo -u postgres psql -c "DROP USER IF EXISTS $EXPORTER_USER;" || true

# Remove pg_stat_statements extension (optional - comment out if you want to keep it)
# echo "Dropping pg_stat_statements extension..."
# sudo -u postgres psql -d postgres -c "DROP EXTENSION IF EXISTS pg_stat_statements;" || true

echo ""
echo "=========================================="
echo "Cleanup Complete"
echo "=========================================="
echo "The following items have been removed:"
echo "  - postgres_exporter service"
echo "  - Exporter directory: $EXPORTER_DIR"
echo "  - Configuration directory: /etc/postgres_exporter"
echo "  - PostgreSQL user '$EXPORTER_USER'"
echo ""
echo "Note: pg_stat_statements extension was NOT removed."
echo "To remove it manually, run:"
echo "  sudo -u postgres psql -d postgres -c 'DROP EXTENSION pg_stat_statements;'"
echo "=========================================="
