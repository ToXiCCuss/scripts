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

echo "Starting cleanup for database: $DB_NAME"
echo "------------------------------------------"

psql_cmd() {
  sudo -u postgres psql "$@"
}

# 1. Terminate active connections to the database (Force Drop)
# This prevents the "database is being accessed by other users" error
psql_cmd -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();"

# 2. Drop the database
psql_cmd -c "DROP DATABASE IF EXISTS \"$DB_NAME\";"

# 3. Drop all users that start with the database name
# (excluding the predefined roles, which are handled in step 4)
USERS=$(psql_cmd -tAc "SELECT rolname FROM pg_roles WHERE rolname LIKE '${DB_NAME}_%' AND rolcanlogin = true;")

if [ -n "$USERS" ]; then
  echo "Found matching users to delete:"
  while read -r USER; do
    echo "  - $USER"
    psql_cmd -c "DROP USER IF EXISTS \"$USER\";"
  done <<< "$USERS"
else
  echo "No matching users found."
fi

# 4. Drop the database-specific roles
psql_cmd -c "DROP ROLE IF EXISTS \"$ROLE_RO\", \"$ROLE_RW\", \"$ROLE_OWNER\";"

echo "------------------------------------------"
echo "Cleanup for $DB_NAME completed successfully."
