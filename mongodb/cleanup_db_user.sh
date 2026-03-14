#!/bin/bash

# Prüfen, ob ein Datenbankname übergeben wurde
if [ -z "$1" ]; then
  echo "Usage: $0 <database_name>"
  exit 1
fi

DB_NAME=$1

echo "Cleaning up Database: $DB_NAME"
echo "This will delete the database and all its users in this database."
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
db.dropDatabase()
EOF

if [ $? -eq 0 ]; then
  echo "------------------------------------------"
  echo "Database $DB_NAME and its users have been deleted successfully."
else
  echo "------------------------------------------"
  echo "Error during cleanup."
  exit 1
fi
