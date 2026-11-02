#!/usr/bin/env bash
# Preserve the stream for apt-listchanges' log; show it on a controlling terminal.
set -euo pipefail
if ( : > /dev/tty ) 2>/dev/null; then
  tee /dev/tty
else
  cat
fi
