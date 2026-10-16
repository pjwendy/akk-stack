#!/bin/sh
# Ensure the MariaDB log file exists before fail2ban tries to watch it
mkdir -p /mariadb/var/log/mysql
touch /mariadb/var/log/mysql/error.log
exec /entrypoint.sh "$@"
