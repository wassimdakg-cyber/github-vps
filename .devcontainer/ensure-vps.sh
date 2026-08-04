#!/bin/bash
# Ensure the VPS stack is running. Idempotent - fast when already up.
# Starts any missing pieces (desktop, audio, rustdesk, websockify).
export XDG_RUNTIME_DIR=/tmp/runtime-codespace
export DISPLAY=:1
export PULSE_SERVER=unix:/tmp/runtime-codespace/pulse/native
mkdir -p $XDG_RUNTIME_DIR 2>/dev/null
chmod 700 $XDG_RUNTIME_DIR 2>/dev/null

if ! pgrep -f "Xvnc :1" >/dev/null 2>&1; then
  echo "VPS desktop not running - running full setup..."
  bash /workspaces/github-vps/.devcontainer/setup.sh
  echo "SETUP_DONE"
  exit 0
fi

echo "desktop is up - checking extras..."
started=0
if ! pgrep -x pipewire >/dev/null 2>&1; then
  setsid nohup pipewire > /tmp/pipewire.log 2>&1 < /dev/null &
  echo "started pipewire"; started=1
fi
if ! pgrep -x pipewire-pulse >/dev/null 2>&1; then
  setsid nohup pipewire-pulse > /tmp/pipewire.log 2>&1 < /dev/null &
  echo "started pipewire-pulse"; started=1
fi
if ! pgrep -x wireplumber >/dev/null 2>&1; then
  setsid nohup wireplumber > /tmp/pipewire.log 2>&1 < /dev/null &
  echo "started wireplumber"; started=1
fi
if [ "$started" = "1" ]; then
  sleep 4
  pactl load-module module-null-sink sink_name=virtual_sink 2>/dev/null
  pactl set-default-sink virtual_sink 2>/dev/null
  pactl set-default-source virtual_sink.monitor 2>/dev/null
fi
if ! pgrep -x rustdesk >/dev/null 2>&1; then
  setsid nohup rustdesk --server > /tmp/rustdesk-server.log 2>&1 < /dev/null &
  echo "started rustdesk server"
fi
if ! pgrep -f "rustdesk --tray" >/dev/null 2>&1; then
  setsid nohup rustdesk --tray > /tmp/rustdesk-tray.log 2>&1 < /dev/null &
  echo "started rustdesk tray"
fi
if ! pgrep -f "websockify" >/dev/null 2>&1; then
  WEBSOCKIFY="$(command -v /tmp/venv/bin/websockify || command -v websockify || echo /tmp/venv/bin/websockify)"
  setsid nohup $WEBSOCKIFY --web /tmp/noVNC 6080 localhost:5901 > /tmp/novnc.log 2>&1 < /dev/null &
  echo "started websockify"
fi
echo "VPS_OK"
