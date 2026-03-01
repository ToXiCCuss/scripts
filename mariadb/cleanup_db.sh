#!/bin/bash

# Check if a database name was provided
if [ -z "$1" ]; then
  echo "Usage: $0 <database_name>"
  exit 1
fi

DB_NAME=$1
DB_USER="${DB_NAME}_owner"

# Define role names based on the database name (must match the setup script)
ROLE_RO="${DB_NAME}_role_ro"
ROLE_RW="${DB_NAME}_role_rw"
ROLE_OWNER="${DB_NAME}_role_owner"

echo "Starting cleanup for MariaDB database: $DB_NAME"
echo "------------------------------------------"

# 1. Drop the database
mariadb -u root -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;"

# 2. Drop all users that start with the database name
# (excluding the roles, which are handled in step 3)
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

# 3. Drop the database-specific roles
mariadb -u root <<EOF
  DROP ROLE IF EXISTS "$ROLE_RO", "$ROLE_RW", "$ROLE_OWNER";
  FLUSH PRIVILEGES;
EOF

if [ $? -eq 0 ]; then
  echo "------------------------------------------"
  echo "Cleanup for $DB_NAME completed successfully."
else
  echo "Error during cleanup."
fi
