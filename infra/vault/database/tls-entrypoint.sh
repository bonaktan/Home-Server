#!/bin/sh
set -eu
case "$1" in
  postgres) owner=postgres; entrypoint=/usr/local/bin/docker-entrypoint.sh ;;
  mariadbd) owner=mysql; entrypoint=/usr/local/bin/docker-entrypoint.sh ;;
  *) echo 'Expected postgres or mariadbd' >&2; exit 1 ;;
esac
mkdir -p /run/database-tls
cp /tls-source/server.pem /run/database-tls/server.pem
cp /tls-source/server-key.pem /run/database-tls/server-key.pem
chown -R "$owner:$owner" /run/database-tls
chmod 600 /run/database-tls/server-key.pem
exec "$entrypoint" "$@"
