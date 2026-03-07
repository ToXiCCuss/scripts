#!/bin/bash

# Check if required arguments are provided
if [ -z "$1" ]; then
  echo "Usage: $0 <username> [host]"
  echo "Example: $1 myuser '%'"
  exit 1
fi

NEW_USER=$1
HOST=${2:-"%"}

# --- AUTOMATISCHE PASSWORT-GENERIERUNG ---
USER_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 30)

echo "Resetting MariaDB Password for: $NEW_USER@$HOST"
echo "New Password:                  $USER_PASS"
echo "------------------------------------------"

mariadb -u root <<EOF
  ALTER USER "$NEW_USER"@"$HOST" IDENTIFIED BY "$USER_PASS";
  FLUSH PRIVILEGES;
EOF

if [ $? -eq 0 ]; then
  echo "------------------------------------------"
  echo "Password for '$NEW_USER'@'$HOST' updated successfully."
  echo "MAKE SURE TO SAVE THE NEW PASSWORD: $USER_PASS"
else
  echo "Error resetting password."
  exit 1
fi
