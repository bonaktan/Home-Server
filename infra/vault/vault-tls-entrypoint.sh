#!/bin/sh
set -eu

mkdir -p /vault/tls
mkdir -p /vault/audit
cp -L /vault/tls-source/fullchain.pem /vault/tls/fullchain.pem
cp -L /vault/tls-source/privkey.pem /vault/tls/privkey.pem
chown vault:vault /vault/tls/fullchain.pem /vault/tls/privkey.pem
chown vault:vault /vault/audit
chmod 0644 /vault/tls/fullchain.pem
chmod 0600 /vault/tls/privkey.pem
chmod 0700 /vault/audit

exec /usr/local/bin/docker-entrypoint.sh "$@"
