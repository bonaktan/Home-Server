#!/usr/bin/env bash
# File-level preview only; effective APT settings and readiness need separate checks.
set -euo pipefail
[ "$#" -eq 1 ] && [ "$1" = plan ] || { printf '%s\n' 'Only package plan is available.' >&2; exit 2; }
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
compare() {
  local source=$1 target=$2
  if [ -L "$target" ]; then
    printf 'unsafe symlink: %s\n' "$target"
  elif [ ! -e "$target" ]; then
    printf 'missing: %s\n' "$target"
  elif [ ! -f "$target" ] || [ ! -r "$target" ]; then
    printf 'unreadable or nonregular: %s\n' "$target"
  elif cmp -s -- "$source" "$target"; then
    printf 'matches: %s\n' "$target"
  else
    printf 'differs: %s\n' "$target"
  fi
}
compare "$repo/infra/host/apt/listchanges.conf" /etc/apt/listchanges.conf.d/home-server.conf
compare "$repo/scripts/host/listchanges-output.sh" /usr/local/libexec/home-server/listchanges-output.sh
compare "$repo/infra/host/logrotate/home-server" /etc/logrotate.d/home-server
compare "$repo/infra/host/motd/95-apt-changes" /etc/update-motd.d/95-apt-changes
if [ -e /etc/apt/apt.conf.d/05listchanges-redirect ] || [ -L /etc/apt/apt.conf.d/05listchanges-redirect ]; then
  printf '%s\n' 'Competing hook exists; adoption and retirement require the package gate.'
else
  printf '%s\n' 'Competing hook not found; confirm privileged inventory.'
fi
printf '%s\n' 'File comparison alone does not verify effective settings, permissions, or the package hook.'
