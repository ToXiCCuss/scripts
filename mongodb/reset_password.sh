#!/bin/bash

# Prüfen auf erforderliche Parameter
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <database_name> <username>"
  exit 1
fi

DB_NAME=$1
DB_USER=$2

# Generiert ein zufälliges 30-stelliges Passwort
DB_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 30)

echo "Database:  $DB_NAME"
echo "Username:  $DB_USER"
echo "New Password:  $DB_PASS"
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

# Nutzt mongosh zur Passwortänderung
mongosh $AUTH_ARGS --quiet <<EOF
use $DB_NAME
db.changeUserPassword("$DB_USER", "$DB_PASS")
EOF

if [ $? -eq 0 ]; then
  echo "------------------------------------------"
  echo "Password for $DB_USER in database $DB_NAME updated successfully."
  echo "MAKE SURE TO SAVE THE NEW PASSWORD: $DB_PASS"
else
  echo "------------------------------------------"
  echo "Error resetting password."
  exit 1
fi
