#!/bin/bash
set -e

EXPORTER_PASSWORD="${EXPORTER_PASSWORD:-$(openssl rand -base64 32)}"
LISTEN_ADDRESS="${LISTEN_ADDRESS:-0.0.0.0:9104}"

echo "Installing mysqld_exporter..."
apt update
apt install -y prometheus-mysqld-exporter

echo "Creating MariaDB user for exporter..."
mariadb -e "CREATE USER IF NOT EXISTS 'exporter'@'localhost' IDENTIFIED BY '${EXPORTER_PASSWORD}' WITH MAX_USER_CONNECTIONS 3;"
mariadb -e "GRANT PROCESS, REPLICATION CLIENT, SELECT, SLAVE MONITOR ON *.* TO 'exporter'@'localhost';"
mariadb -e "FLUSH PRIVILEGES;"

echo "Creating exporter config..."
cat > /etc/mysql/mysqld_exporter.cnf <<EOF
[client]
user=exporter
password=${EXPORTER_PASSWORD}
EOF

chown prometheus:prometheus /etc/mysql/mysqld_exporter.cnf
chmod 600 /etc/mysql/mysqld_exporter.cnf

echo "Creating systemd service..."
cat > /etc/systemd/system/mysql_exporter.service <<EOF
[Unit]
Description=Prometheus MySQL Exporter
After=network.target mariadb.service

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecStart=/usr/bin/prometheus-mysqld-exporter \\
  --config.my-cnf=/etc/mysql/mysqld_exporter.cnf \\
  --web.listen-address=${LISTEN_ADDRESS}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mysql_exporter
systemctl restart mysql_exporter

echo "mysqld_exporter setup complete!"
echo "Password: ${EXPORTER_PASSWORD}"
echo "Listening on: ${LISTEN_ADDRESS}"
