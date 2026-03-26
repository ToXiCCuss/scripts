#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root!"
  exit 1
fi

echo "=========================================="
echo "Node Exporter Cleanup"
echo "=========================================="
echo ""

echo "Stopping and disabling service..."
systemctl stop prometheus-node-exporter || true
systemctl disable prometheus-node-exporter || true

echo "Removing package..."
if dpkg -l | grep -q prometheus-node-exporter; then
    apt remove -y prometheus-node-exporter
    apt purge -y prometheus-node-exporter
fi

echo "Removing configuration files..."
rm -f /etc/default/prometheus-node-exporter
systemctl daemon-reload

echo ""
echo "=========================================="
echo "Cleanup Complete"
echo "=========================================="
echo "The following items have been removed:"
echo "  - prometheus-node-exporter service"
echo "  - prometheus-node-exporter package"
echo "  - /etc/default/prometheus-node-exporter"
echo "=========================================="
