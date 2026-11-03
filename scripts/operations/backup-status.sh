#!/usr/bin/env bash
# Input must come from a trusted collector; collection is not yet enrolled.
set -euo pipefail
base=$(dirname "$(readlink -f "$0")")
if [ "$#" -eq 0 ]; then
  exec python3 "$base/backup_status.py"
elif [ "$#" -eq 2 ] && [ "$1" = --persist ]; then
  exec python3 "$base/backup_status_store.py" "$2"
fi
printf '%s\n' 'Usage: backup-status.sh [--persist r2|second_server]' >&2
exit 2
