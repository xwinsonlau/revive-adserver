#!/bin/bash
set -e

APP_DIR=/var/www/html
DB_HOST="${DB_HOST:-db}"
DB_PORT="${DB_PORT:-3306}"

echo "Waiting for database at ${DB_HOST}:${DB_PORT}..."
until (exec 3<>"/dev/tcp/${DB_HOST}/${DB_PORT}") 2>/dev/null; do
    sleep 1
done
exec 3<&- 3>&-
echo "Database is reachable."

INSTALL_MARKER="${APP_DIR}/var/.docker-install-complete"

if [ ! -f "${INSTALL_MARKER}" ]; then
    echo "No completed install marker found, running the Revive Adserver CLI installer..."

    INSTALLER_CONF=/tmp/installer.conf.php
    cat > "${INSTALLER_CONF}" <<EOF
;<?php exit; ?>
;*** DO NOT REMOVE THE LINE ABOVE ***

[database]
type      = "mysqli"
host      = "${DB_HOST}"
name      = "${MYSQL_DATABASE}"
socket    =
port      = "${DB_PORT}"
username  = "${MYSQL_USER}"
password  = "${MYSQL_PASSWORD}"

[table]
prefix  = "rv_"
type    = "INNODB"

[admin]
username  = "${ADMIN_USERNAME}"
password  = "${ADMIN_PASSWORD}"
email     = "${ADMIN_EMAIL}"
language  = "en"
timezone  =

[paths]
requireSSL = 0
admin      = "${APP_HOST}/www/admin"
delivery   = "${APP_HOST}/www/delivery"
images     = "${APP_HOST}/www/images"
imageStore =
EOF

    (cd "${APP_DIR}" && php scripts/installer install "${INSTALLER_CONF}" --force)
    rm -f "${INSTALLER_CONF}"
    touch "${INSTALL_MARKER}"

    echo "Install complete."
else
    echo "Install marker found, skipping installer."
fi

chown -R www-data:www-data \
    "${APP_DIR}/var" \
    "${APP_DIR}/plugins" \
    "${APP_DIR}/www/images" \
    "${APP_DIR}/www/admin/plugins" 2>/dev/null || true

exec "$@"
