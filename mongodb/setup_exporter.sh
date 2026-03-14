#!/bin/bash
set -e

# MongoDB Exporter auf Debian 13 (Trixie) einrichten

if [ "$EUID" -ne 0 ]; then
  echo "Bitte führen Sie dieses Skript als root aus!"
  exit 1
fi

EXPORTER_USER="mongodb_exporter"
EXPORTER_PASSWORD="${EXPORTER_PASSWORD:-$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 32)}"
LISTEN_ADDRESS="${LISTEN_ADDRESS:-0.0.0.0:9216}"
MONGODB_URI="${MONGODB_URI:-mongodb://localhost:27017}"

echo "Installiere prometheus-mongodb-exporter..."
apt update
apt install -y prometheus-mongodb-exporter

echo "Erstelle MongoDB-Benutzer für den Exporter..."
# Wir versuchen den Benutzer in der 'admin' Datenbank anzulegen
# Er benötigt clusterMonitor Rechte für globale Statistiken und read für Datenbank-Statistiken

CONFIG_FILE="/etc/mongodb-admin.cred"
AUTH_ARGS=""
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    if [ -n "$ADMIN_USER" ] && [ -n "$ADMIN_PASS" ]; then
        AUTH_ARGS="-u $ADMIN_USER -p $ADMIN_PASS --authenticationDatabase admin"
    fi
fi

mongosh $AUTH_ARGS --quiet <<EOF
use admin
db.createUser({
  user: "${EXPORTER_USER}",
  pwd: "${EXPORTER_PASSWORD}",
  roles: [
    { role: "clusterMonitor", db: "admin" },
    { role: "read", db: "local" }
  ]
})
EOF

echo "Konfiguriere prometheus-mongodb-exporter..."
# Debian nutzt /etc/default/prometheus-mongodb-exporter
# Die URI muss den neuen Benutzer enthalten.

# URL-Encoding für das Passwort (falls Sonderzeichen enthalten wären, 
# hier haben wir sie oben auf alnum eingeschränkt, zur Sicherheit trotzdem sauber)
# Da wir tr -dc 'a-zA-Z0-9' nutzen, ist kein spezielles Encoding nötig.

cat > /etc/default/prometheus-mongodb-exporter <<EOF
MONGODB_URI="mongodb://${EXPORTER_USER}:${EXPORTER_PASSWORD}@localhost:27017/admin?authSource=admin"
ARGS="--web.listen-address=${LISTEN_ADDRESS}"
EOF

echo "Starte und aktiviere prometheus-mongodb-exporter Dienst..."
systemctl restart prometheus-mongodb-exporter
systemctl enable prometheus-mongodb-exporter

echo "MongoDB Exporter Setup abgeschlossen!"
echo "Benutzer: ${EXPORTER_USER}"
echo "Passwort: ${EXPORTER_PASSWORD}"
echo "Listening on: ${LISTEN_ADDRESS}"
