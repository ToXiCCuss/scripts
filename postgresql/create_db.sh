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

DB_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 30)

echo "Creating Database: $DB_NAME"
echo "Creating User:     $DB_USER"
echo "Roles:             $ROLE_RO, $ROLE_RW, $ROLE_OWNER"
echo "Password:          $DB_PASS"
echo "------------------------------------------"

psql_cmd() {
  sudo -u postgres psql "$@"
}

psql_cmd -c "REVOKE CONNECT ON DATABASE postgres FROM PUBLIC;"

psql_cmd -c "CREATE DATABASE \"$DB_NAME\";"

psql_cmd -d "$DB_NAME" <<EOF
  CREATE ROLE "$ROLE_RO";
  CREATE ROLE "$ROLE_RW";
  CREATE ROLE "$ROLE_OWNER";

  REVOKE ALL ON SCHEMA public FROM PUBLIC;
  REVOKE ALL ON DATABASE "$DB_NAME" FROM PUBLIC;

  ALTER SCHEMA public OWNER TO "$ROLE_OWNER";

  GRANT USAGE ON SCHEMA public TO "$ROLE_RO", "$ROLE_RW", "$ROLE_OWNER";
  GRANT CREATE ON SCHEMA public TO "$ROLE_OWNER";

  ALTER DEFAULT PRIVILEGES GRANT SELECT ON TABLES TO "$ROLE_RO";
  ALTER DEFAULT PRIVILEGES GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "$ROLE_RW";
  ALTER DEFAULT PRIVILEGES GRANT ALL ON TABLES TO "$ROLE_OWNER";

  CREATE USER "$DB_USER" WITH PASSWORD '$DB_PASS';
  GRANT "$ROLE_OWNER" TO "$DB_USER";

  REVOKE CONNECT ON DATABASE "$DB_NAME" FROM PUBLIC;
  GRANT CONNECT ON DATABASE "$DB_NAME" TO "$ROLE_RO", "$ROLE_RW", "$ROLE_OWNER";
EOF

echo "------------------------------------------"
echo "Setup for $DB_NAME completed successfully."
