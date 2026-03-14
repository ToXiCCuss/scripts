#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root!"
  exit 1
fi

LISTEN_ADDRESS="${LISTEN_ADDRESS:-0.0.0.0:9100}"

echo "Installing prometheus-node-exporter..."
apt update
apt install -y prometheus-node-exporter

echo "Configuring Node Exporter..."

cat > /etc/default/prometheus-node-exporter <<EOF
ARGS="--web.listen-address=${LISTEN_ADDRESS} \
--collector.mountstats \
--collector.logind \
--collector.processes \
--collector.systemd"
EOF

echo "Starting and enabling Node Exporter service..."
systemctl restart prometheus-node-exporter
systemctl enable prometheus-node-exporter

echo "Node Exporter setup completed!"
echo "Listening on: ${LISTEN_ADDRESS}"
