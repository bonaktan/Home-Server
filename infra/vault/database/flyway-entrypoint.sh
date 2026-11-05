#!/bin/sh
set -eu
: "${FLYWAY_USER:?Run this job through infra/vault/database/migrate.py}"
: "${FLYWAY_PASSWORD:?Run this job through infra/vault/database/migrate.py}"
exec /flyway/flyway "$@"
