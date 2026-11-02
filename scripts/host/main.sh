#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' 'Usage: setup.sh [inspect | plan PHASE | apply PHASE | verify PHASE]'
}

case "${1:-inspect}" in
  inspect)
    if [ "$#" -gt 1 ]; then usage >&2; exit 2; fi
    printf 'Host: %s\n' "$(hostname)"
    printf 'Kernel: %s\n' "$(uname -r)"
    if [ -r /etc/os-release ]; then
      # Only select fixed, nonsecret OS metadata; do not print the environment.
      awk -F= '/^(PRETTY_NAME|VERSION_ID)=/ {print}' /etc/os-release
    fi
    printf '%s\n' 'Inventory and readiness gates: docs/operations/inventory.md'
    ;;
  plan|apply|verify)
    if [ "$#" -ne 2 ]; then usage >&2; exit 2; fi
    case "$2" in
      packages|hardware|network|access|firewall|audit|schedules) ;;
      *) printf '%s\n' 'Unknown phase.' >&2; exit 2 ;;
    esac
    printf '%s\n' 'Phase is not implemented or enrolled; no changes made.' >&2
    exit 1
    ;;
  -h|--help|help)
    if [ "$#" -ne 1 ]; then usage >&2; exit 2; fi
    usage
    ;;
  *) usage >&2; exit 2 ;;
esac
