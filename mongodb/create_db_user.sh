#!/bin/bash

# Prüfen, ob ein Datenbankname übergeben wurde
if [ -z "$1" ]; then
  echo "Usage: $0 <database_name>"
  exit 1
fi

DB_NAME=$1
DB_USER="${DB_NAME}_owner"
ROLES_JSON="{ role: \"dbOwner\", db: \"$DB_NAME\" }"

# Generiert ein zufälliges 30-stelliges Passwort
DB_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 30)

echo "Creating Database: $DB_NAME"
echo "Creating User:     $DB_USER"
echo "Role:              dbOwner"
echo "Password:          $DB_PASS"
echo "------------------------------------------"

# MongoDB Befehle ausführen
# Falls Authentifizierung aktiv ist, können ADMIN_USER und ADMIN_PASS hier geladen werden
CONFIG_FILE="/etc/mongodb-admin.cred"
AUTH_ARGS=""
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    if [ -n "$ADMIN_USER" ] && [ -n "$ADMIN_PASS" ]; then
        AUTH_ARGS="-u $ADMIN_USER -p $ADMIN_PASS --authenticationDatabase admin"
    fi
fi

# Nutzt die Localhost-Exception oder setzt voraus, dass der User Admin-Rechte hat
mongosh $AUTH_ARGS --quiet <<EOF
use $DB_NAME
db.createUser({
  user: "$DB_USER",
  pwd: "$DB_PASS",
  roles: [ $ROLES_JSON ]
})
EOF

if [ $? -eq 0 ]; then
  echo "------------------------------------------"
  echo "Setup for $DB_NAME completed successfully."
else
  echo "------------------------------------------"
  echo "Error during setup."
  exit 1
fi
