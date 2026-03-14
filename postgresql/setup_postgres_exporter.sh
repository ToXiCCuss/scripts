#!/bin/bash

# PostgreSQL Exporter Setup Script
# This script sets up postgres_exporter with all collectors enabled

set -e

echo "=========================================="
echo "PostgreSQL Exporter Setup"
echo "=========================================="
echo ""

# Variables
EXPORTER_USER="postgres_exporter"
EXPORTER_PASSWORD=$(openssl rand -base64 32)
EXPORTER_VERSION="0.15.0"
EXPORTER_DIR="/opt/postgres_exporter"
CONFIG_FILE="/etc/postgres_exporter/postgres_exporter.yml"
SERVICE_FILE="/etc/systemd/system/postgres_exporter.service"
EXPORTER_PORT="9187"

# Create PostgreSQL user for exporter
echo "Creating PostgreSQL user: $EXPORTER_USER"
sudo -u postgres psql <<EOF
CREATE USER $EXPORTER_USER WITH PASSWORD '$EXPORTER_PASSWORD';
ALTER USER $EXPORTER_USER SET SEARCH_PATH TO $EXPORTER_USER,pg_catalog;
GRANT pg_monitor TO $EXPORTER_USER;
EOF

echo "User created successfully"
echo ""

# Download and install postgres_exporter
echo "Downloading postgres_exporter v$EXPORTER_VERSION..."
cd /tmp
wget https://github.com/prometheus-community/postgres_exporter/releases/download/v${EXPORTER_VERSION}/postgres_exporter-${EXPORTER_VERSION}.linux-amd64.tar.gz
tar xvfz postgres_exporter-${EXPORTER_VERSION}.linux-amd64.tar.gz

echo "Installing postgres_exporter..."
sudo mkdir -p $EXPORTER_DIR
sudo mv postgres_exporter-${EXPORTER_VERSION}.linux-amd64/postgres_exporter $EXPORTER_DIR/
sudo chown -R postgres:postgres $EXPORTER_DIR
sudo chmod +x $EXPORTER_DIR/postgres_exporter

# Create config directory
sudo mkdir -p /etc/postgres_exporter
sudo chown postgres:postgres /etc/postgres_exporter

# Create configuration file
echo "Creating configuration file..."
sudo tee $CONFIG_FILE > /dev/null <<EOF
# PostgreSQL connection string
# Format: postgresql://username:password@hostname:port/database?sslmode=disable
DATA_SOURCE_NAME=postgresql://$EXPORTER_USER:$EXPORTER_PASSWORD@localhost:5432/postgres?sslmode=disable
EOF

sudo chown postgres:postgres $CONFIG_FILE
sudo chmod 600 $CONFIG_FILE

# Create systemd service file with ALL collectors enabled
echo "Creating systemd service..."
sudo tee $SERVICE_FILE > /dev/null <<EOF
[Unit]
Description=PostgreSQL Exporter
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=postgres
Group=postgres
EnvironmentFile=$CONFIG_FILE
ExecStart=$EXPORTER_DIR/postgres_exporter \\
  --web.listen-address=:$EXPORTER_PORT \\
  --web.telemetry-path=/metrics \\
  --collector.database \\
  --collector.database_wraparound \\
  --collector.locks \\
  --collector.long_running_transactions \\
  --collector.postmaster \\
  --collector.process_idle \\
  --collector.replication \\
  --collector.replication_slot \\
  --collector.stat_activity_autovacuum \\
  --collector.stat_bgwriter \\
  --collector.stat_checkpointer \\
  --collector.stat_database \\
  --collector.stat_progress_vacuum \\
  --collector.stat_statements \\
  --collector.stat_statements.include_query \\
  --collector.stat_statements.query_length=500 \\
  --collector.stat_statements.limit=500 \\
  --collector.stat_user_tables \\
  --collector.stat_wal_receiver \\
  --collector.statio_user_indexes \\
  --collector.statio_user_tables \\
  --collector.wal \\
  --collector.xlog_location \\
  --log.level=info \\
  --log.format=logfmt

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable pg_stat_statements extension
echo ""
echo "Enabling pg_stat_statements extension..."
sudo -u postgres psql -d postgres <<EOF
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
EOF

echo ""
echo "=========================================="
echo "Installation Summary"
echo "=========================================="
echo "Exporter User: $EXPORTER_USER"
echo "Exporter Password: $EXPORTER_PASSWORD"
echo "Exporter Directory: $EXPORTER_DIR"
echo "Config File: $CONFIG_FILE"
echo "Service File: $SERVICE_FILE"
echo "Metrics URL: http://localhost:$EXPORTER_PORT/metrics"
echo ""
echo "All collectors enabled:"
echo "  - database"
echo "  - database_wraparound"
echo "  - locks"
echo "  - long_running_transactions"
echo "  - postmaster"
echo "  - process_idle"
echo "  - replication"
echo "  - replication_slot"
echo "  - stat_activity_autovacuum"
echo "  - stat_bgwriter"
echo "  - stat_checkpointer"
echo "  - stat_database"
echo "  - stat_progress_vacuum"
echo "  - stat_statements (with query text, length=500, limit=500)"
echo "  - stat_user_tables"
echo "  - stat_wal_receiver"
echo "  - statio_user_indexes"
echo "  - statio_user_tables"
echo "  - wal"
echo "  - xlog_location"
echo ""
echo "To start the service, run:"
echo "  sudo systemctl daemon-reload"
echo "  sudo systemctl enable postgres_exporter"
echo "  sudo systemctl start postgres_exporter"
echo ""
echo "To check status:"
echo "  sudo systemctl status postgres_exporter"
echo ""
echo "To view metrics:"
echo "  curl http://localhost:$EXPORTER_PORT/metrics"
echo "=========================================="
