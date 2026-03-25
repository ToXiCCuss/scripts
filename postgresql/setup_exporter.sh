#!/bin/bash
set -e

EXPORTER_PASSWORD="${EXPORTER_PASSWORD:-$(openssl rand -base64 32)}"

echo "------------------------------------"
echo "Creating PostgreSQL exporter user..."
echo "------------------------------------"

sudo -u postgres psql <<SQL
CREATE USER prometheus WITH PASSWORD '${EXPORTER_PASSWORD}';
GRANT pg_monitor TO prometheus;

DO \$\$
DECLARE
  db TEXT;
BEGIN
  FOR db IN SELECT datname FROM pg_database WHERE datistemplate = false LOOP
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO prometheus', db);
  END LOOP;
END;
\$\$;

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
SQL

echo "------------------------------------"
echo "Done!"
echo "Password: ${EXPORTER_PASSWORD}"
echo "------------------------------------"
