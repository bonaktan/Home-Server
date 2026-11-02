#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' 'new_setup.sh is deprecated; use setup.sh.' >&2
exec "$(dirname "$(readlink -f "$0")")/setup.sh" "$@"
