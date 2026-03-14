#!/bin/bash
set -e

h # URL-encode function
urlencode() {
    local string="${1}"
    local strlen=${#string}
    local encoded=""
    local pos c o

    for (( pos=0 ; pos<strlen ; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9] ) o="${c}" ;;
            * ) printf -v o '%%%02x' "'$c"
        esac
        encoded+="${o}"
    done
    echo "${encoded}"
}

EXPORTER_PASSWORD="${EXPORTER_PASSWORD:-$(openssl rand -base64 32)}"
EXPORTER_PASSWORD_ENCODED=$(urlencode "${EXPORTER_PASSWORD}")
DB_NAME="${DB_NAME:-postgres}"
LISTEN_ADDRESS="${LISTEN_ADDRESS:-0.0.0.0:9187}"

echo "Installing postgres_exporter..."
apt update
apt install -y prometheus-postgres-exporter

echo "Creating PostgreSQL user for exporter..."
sudo -u postgres psql -c "CREATE USER prometheus WITH PASSWORD '${EXPORTER_PASSWORD}';"
sudo -u postgres psql -c "GRANT pg_monitor TO prometheus;"

echo "Enabling pg_stat_statements extension..."
sudo -u postgres psql -d ${DB_NAME} -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"

echo "Configuring postgres_exporter..."
cat > /etc/default/prometheus-postgres-exporter <<EOF
DATA_SOURCE_NAME="postgresql://prometheus:${EXPORTER_PASSWORD}@localhost:5432/${DB_NAME}?sslmode=disable"
ARGS="--web.listen-address=${LISTEN_ADDRESS} \
--web.telemetry-path=/metrics \
--collector.database \
--collector.database_wraparound \
--collector.locks \
--collector.long_running_transactions \
--collector.postmaster \
--collector.process_idle \
--collector.replication \
--collector.replication_slot \
--collector.roles \
--collector.stat_activity_autovacuum \
--collector.stat_bgwriter \
--collector.stat_checkpointer \
--collector.stat_database \
--collector.stat_statements \
--collector.stat_user_tables \
--collector.stat_wal_receiver \
--collector.statio_user_indexes \
--collector.statio_user_tables \
--collector.wal \
--collector.xlog_location
EOF

systemctl restart prometheus-postgres-exporter
systemctl enable prometheus-postgres-exporter

echo "postgres_exporter setup complete!"
echo "Password: ${EXPORTER_PASSWORD}"
echo "Listening on: ${LISTEN_ADDRESS}"
