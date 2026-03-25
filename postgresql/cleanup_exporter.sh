#!/bin/bash
set -e

echo "---------------------------------------"
echo "Cleaning up PostgreSQL exporter user..."
echo "---------------------------------------"

sudo -u postgres psql <<SQL
-- Revoke CONNECT von allen DBs
DO \$\$
DECLARE
  db TEXT;
BEGIN
  FOR db IN SELECT datname FROM pg_database WHERE datistemplate = false LOOP
    EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM prometheus', db);
  END LOOP;
END;
\$\$;

REVOKE pg_monitor FROM prometheus;
DROP USER IF EXISTS prometheus;
SQL

echo "---------------------------------------"
echo "Done!"
echo "---------------------------------------"
