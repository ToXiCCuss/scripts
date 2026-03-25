#!/bin/bash
set -e

EXPORTER_PASSWORD="${EXPORTER_PASSWORD:-$(openssl rand -base64 32)}"

echo "Creating MariaDB user for exporter..."
mariadb -e "CREATE USER IF NOT EXISTS 'exporter'@'localhost' IDENTIFIED BY '${EXPORTER_PASSWORD}' WITH MAX_USER_CONNECTIONS 3;"
mariadb -e "GRANT PROCESS, REPLICATION CLIENT, SELECT, SLAVE MONITOR ON *.* TO 'exporter'@'localhost';"
mariadb -e "FLUSH PRIVILEGES;"

echo "mysqld_exporter user setup complete!"
echo "Password: ${EXPORTER_PASSWORD}"
