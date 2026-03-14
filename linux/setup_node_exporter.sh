#!/bin/bash
set -e

# Node Exporter auf Debian 13 (Trixie) einrichten

if [ "$EUID" -ne 0 ]; then
  echo "Bitte führen Sie dieses Skript als root aus!"
  exit 1
fi

LISTEN_ADDRESS="${LISTEN_ADDRESS:-0.0.0.0:9100}"

echo "Installiere prometheus-node-exporter..."
apt update
apt install -y prometheus-node-exporter

echo "Konfiguriere Node Exporter (falls nötig)..."
# Die Standardkonfiguration unter Debian nutzt /etc/default/prometheus-node-exporter
# Wir passen die LISTEN_ADDRESS an.

cat > /etc/default/prometheus-node-exporter <<EOF
ARGS="--web.listen-address=${LISTEN_ADDRESS} \
--collector.mountstats \
--collector.logind \
--collector.processes \
--collector.systemd"
EOF

echo "Starte und aktiviere Node Exporter Dienst..."
systemctl restart prometheus-node-exporter
systemctl enable prometheus-node-exporter

echo "Node Exporter Setup abgeschlossen!"
echo "Listening on: ${LISTEN_ADDRESS}"
