#!/usr/bin/env bash
# Bounded local observations; do not print command lines, environments or secrets.
set -euo pipefail
printf 'Host: %s\n' "$(hostname)"
printf 'Kernel: %s\n' "$(uname -r)"
if [ -r /etc/os-release ]; then
  awk -F= '/^(PRETTY_NAME|VERSION_ID)=/ {print}' /etc/os-release
fi
if [ -r /proc/meminfo ]; then
  awk '/^(MemTotal|MemAvailable|SwapTotal|SwapFree):/ {print}' /proc/meminfo
fi
printf '%s\n' 'Filesystem capacity:'
df -Pk / /srv
printf '%s\n' 'Filesystem inodes:'
df -Pi / /srv
printf '%s\n' 'Inventory and readiness gates: docs/operations/inventory.md'
