#!/bin/bash
set -e

EXPORTER_PASSWORD="${EXPORTER_PASSWORD:-$(openssl rand -base64 32)}"
DB_NAME="${DB_NAME:-postgres}"
LISTEN_ADDRESS="${LISTEN_ADDRESS:-0.0.0.0:9187}"

echo "Installing postgres_exporter..."
apt update
apt install -y prometheus-postgres-exporter

echo "Creating PostgreSQL user for exporter..."
sudo -u postgres psql -c "CREATE USER prometheus WITH PASSWORD '${EXPORTER_PASSWORD}';"
sudo -u postgres psql -c "GRANT pg_monitor TO prometheus;"

echo "Configuring postgres_exporter..."
cat > /etc/default/prometheus-postgres-exporter <<EOF
DATA_SOURCE_NAME="postgresql://prometheus:${EXPORTER_PASSWORD}@localhost:5432/${DB_NAME}?sslmode=disable"
ARGS="--collector.stat_checkpointer --web.listen-address=${LISTEN_ADDRESS}"
EOF

systemctl restart prometheus-postgres-exporter
systemctl enable prometheus-postgres-exporter

echo "postgres_exporter setup complete!"
echo "Password: ${EXPORTER_PASSWORD}"
echo "Listening on: ${LISTEN_ADDRESS}"
