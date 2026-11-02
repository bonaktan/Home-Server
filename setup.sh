#!/usr/bin/env bash
# Maintained entry point. Host mutations remain disabled until their gates pass.
set -euo pipefail
exec "$(dirname "$(readlink -f "$0")")/scripts/host/main.sh" "$@"
