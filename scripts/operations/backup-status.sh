#!/usr/bin/env bash
# Classify a bounded observation on stdin; destination collection is not yet enrolled.
set -euo pipefail
exec python3 "$(dirname "$(readlink -f "$0")")/backup_status.py"
