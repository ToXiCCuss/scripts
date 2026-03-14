#!/bin/bash

# Check if database and schema names were provided
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <database_name> <new_schema_name>"
  exit 1
fi

DB_NAME=$1
SCHEMA_NAME=$2

# Role names based on the database name (as defined in create_db.sh)
ROLE_RO="${DB_NAME}_role_ro"
ROLE_RW="${DB_NAME}_role_rw"
ROLE_OWNER="${DB_NAME}_role_owner"

echo "Creating schema '$SCHEMA_NAME' in database '$DB_NAME'..."
echo "Setting permissions for $ROLE_RO, $ROLE_RW, and $ROLE_OWNER."
echo "--------------------------------------------------------"

sudo -u postgres psql -d "$DB_NAME" <<EOF
  -- 1. Create schema with the owner role as the authorization holder
  CREATE SCHEMA "$SCHEMA_NAME" AUTHORIZATION "$ROLE_OWNER";

  -- 2. Grant "access" (USAGE) to all roles
  GRANT USAGE ON SCHEMA "$SCHEMA_NAME" TO "$ROLE_RO", "$ROLE_RW", "$ROLE_OWNER";

  -- 3. Grant write permissions to the owner (CREATE within the schema)
  GRANT CREATE ON SCHEMA "$SCHEMA_NAME" TO "$ROLE_OWNER";

  -- 4. Set Default Privileges for future tables IN THIS SCHEMA
  -- (In case they haven't been set globally for the entire database)
  ALTER DEFAULT PRIVILEGES IN SCHEMA "$SCHEMA_NAME" GRANT SELECT ON TABLES TO "$ROLE_RO";
  ALTER DEFAULT PRIVILEGES IN SCHEMA "$SCHEMA_NAME" GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "$ROLE_RW";
  ALTER DEFAULT PRIVILEGES IN SCHEMA "$SCHEMA_NAME" GRANT ALL ON TABLES TO "$ROLE_OWNER";

EOF

if [ $? -eq 0 ]; then
  echo "--------------------------------------------------------"
  echo "Schema '$SCHEMA_NAME' has been successfully configured."
else
  echo "Error creating the schema."
fi
