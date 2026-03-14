#!/bin/bash
set -e

echo "=========================================="
echo "PostgreSQL Exporter Cleanup"
echo "=========================================="
echo ""

# Stop and disable service
echo "Stopping prometheus-postgres-exporter service..."
systemctl stop prometheus-postgres-exporter || true
systemctl disable prometheus-postgres-exporter || true

echo "Removing prometheus-postgres-exporter package..."
apt remove -y prometheus-postgres-exporter || true
apt purge -y prometheus-postgres-exporter || true

# Remove configuration files
echo "Removing configuration files..."
rm -f /etc/default/prometheus-postgres-exporter

# Drop PostgreSQL user
echo "Revoking privileges for PostgreSQL user 'prometheus'..."
sudo -u postgres psql -d postgres -c "REVOKE ALL PRIVILEGES ON DATABASE postgres FROM prometheus;" || true
echo "Dropping PostgreSQL user 'prometheus'..."
sudo -u postgres psql -c "DROP USER IF EXISTS prometheus;" || true

# Remove pg_stat_statements extension (optional - comment out if you want to keep it)
# echo "Dropping pg_stat_statements extension..."
# sudo -u postgres psql -d postgres -c "DROP EXTENSION IF EXISTS pg_stat_statements;" || true

echo ""
echo "=========================================="
echo "Cleanup Complete"
echo "=========================================="
echo "The following items have been removed:"
echo "  - prometheus-postgres-exporter service"
echo "  - Configuration files"
echo "  - PostgreSQL user 'prometheus'"
echo ""
echo "Note: pg_stat_statements extension was NOT removed."
echo "To remove it manually, run:"
echo "  sudo -u postgres psql -d postgres -c 'DROP EXTENSION pg_stat_statements;'"
echo "=========================================="
