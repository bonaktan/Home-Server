#!/bin/ash
set -eu
cd /app
# Include operator-mounted CAs for HTTPS calls to Wings in staging.
update-ca-certificates >/dev/null
# The image clears cached DB credentials after the upstream environment setup.
# Cron runs under supervisord so every child receives the current lease.
exec /bin/ash .github/docker/entrypoint.sh supervisord -n -c /etc/supervisord.conf
