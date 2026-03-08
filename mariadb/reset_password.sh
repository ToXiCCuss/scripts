#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <username> [host]"
  echo "Example: $1 myuser '%'"
  exit 1
fi

NEW_USER=$1
HOST=${2:-"%"}

USER_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 30)

echo "------------------------------------------"
echo "Resetting Password"
echo "User: $NEW_USER@$HOST"
echo "New Password: $USER_PASS"
echo "------------------------------------------"

mariadb -u root <<EOF
  ALTER USER "$NEW_USER"@"$HOST" IDENTIFIED BY "$USER_PASS";
  FLUSH PRIVILEGES;
EOF

if [ $? -eq 0 ]; then
  echo "DONE"
else
  echo "ERROR"
fi
echo "------------------------------------------"

