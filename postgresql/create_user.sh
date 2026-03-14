#!/bin/bash

# Check if required arguments are provided
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
  echo "Usage: $0 <database_name> <new_username> <role_type: ro|rw|owner>"
  exit 1
fi

DB_NAME=$1
NEW_USER="${DB_NAME}_$2"
ROLE_TYPE=$3

# Determine target role based on input
case $ROLE_TYPE in
  ro)
    TARGET_ROLE="${DB_NAME}_role_ro"
    ;;
  rw)
    TARGET_ROLE="${DB_NAME}_role_rw"
    ;;
  owner)
    TARGET_ROLE="${DB_NAME}_role_owner"
    ;;
  *)2
    echo "Error: Invalid role type. Use 'ro', 'rw', or 'owner'."
    exit 1
    ;;
esac

# --- AUTOMATISCHE PASSWORT-GENERIERUNG ---
USER_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 30)

echo "Creating User: $NEW_USER"
echo "Assigning Role: $TARGET_ROLE"
echo "Password:      $USER_PASS"
echo "------------------------------------------"

sudo -u postgres psql -d "$DB_NAME" <<EOF
  -- Create the user with login permissions
  CREATE USER "$NEW_USER" WITH PASSWORD '$USER_PASS';

  -- Grant the specific role to the user
  GRANT "$TARGET_ROLE" TO "$NEW_USER";
EOF

if [ $? -eq 0 ]; then
  echo "------------------------------------------"
  echo "User '$NEW_USER' created and assigned to '$TARGET_ROLE'."
  echo "MAKE SURE TO SAVE THE PASSWORD: $USER_PASS"
else
  echo "Error creating user."
fi
