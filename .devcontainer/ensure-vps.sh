#!/bin/bash
# Ensure the VPS stack is running. Idempotent - fast when already up.
# Usage: bash /workspaces/github-vps/.devcontainer/ensure-vps.sh
if pgrep -f "Xvnc :1" >/dev/null 2>&1; then
  echo "VPS already running (Xvnc :1 up)."
  exit 0
fi
echo "VPS not running - starting setup..."
bash /workspaces/github-vps/.devcontainer/setup.sh
