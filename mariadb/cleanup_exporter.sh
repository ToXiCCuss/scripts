#!/bin/bash
set -e

echo "---------------------------------------"
echo "Cleaning up MariaDB exporter user..."
echo "---------------------------------------"

mariadb -e "REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'exporter'@'localhost';" || true
mariadb -e "DROP USER IF EXISTS 'exporter'@'localhost';"
mariadb -e "FLUSH PRIVILEGES;"

echo "---------------------------------------"
echo "Done!"
echo "---------------------------------------"
