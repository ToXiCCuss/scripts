#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <database_name>"
  exit 1
fi

DB_NAME=$1
DB_USER="${DB_NAME}_owner"

ROLE_RO="${DB_NAME}_role_ro"
ROLE_RW="${DB_NAME}_role_rw"
ROLE_OWNER="${DB_NAME}_role_owner"

echo "------------------------------------------"
echo "cleanup MariaDB database $DB_NAME"
echo "------------------------------------------"

mariadb -u root -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;"

USERS=$(mariadb -u root -sN -e "SELECT user, host FROM mysql.user WHERE user LIKE '${DB_NAME}_%' AND is_role = 'N';")

if [ -n "$USERS" ]; then
  echo "Found matching users to delete:"
  while read -r USER HOST; do
    echo "  - $USER@$HOST"
    mariadb -u root -e "DROP USER IF EXISTS '$USER'@'$HOST';"
  done <<< "$USERS"
else
  echo "No matching users found."
fi

mariadb -u root <<EOF
  DROP ROLE IF EXISTS "$ROLE_RO", "$ROLE_RW", "$ROLE_OWNER";
  FLUSH PRIVILEGES;
EOF

if [ $? -eq 0 ]; then
  echo "------------------------------------------"
  echo "DONE"
else
  echo "ERROR"
fi
