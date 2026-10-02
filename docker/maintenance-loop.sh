#!/bin/bash
set -e

DB_HOST="${DB_HOST:-db}"
DB_PORT="${DB_PORT:-3306}"

until (exec 3<>"/dev/tcp/${DB_HOST}/${DB_PORT}") 2>/dev/null; do
    sleep 1
done
exec 3<&- 3>&-

cd /var/www/html

while true; do
    php scripts/maintenance/maintenance.php localhost
    sleep "${MAINTENANCE_INTERVAL:-300}"
done
