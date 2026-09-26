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
export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket
pkill -f "gnome-session-failed" 2>/dev/null || true
if ! dbus-send --system --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.ListNames >/dev/null 2>&1; then
  echo "system bus dead - reviving"
  sudo rm -f /run/dbus/system_bus_socket /run/dbus/pid 2>/dev/null
  sudo dbus-daemon --system --fork 2>&1
  sleep 1
fi
if ! pgrep -x gnome-shell >/dev/null 2>&1; then
  echo "gnome-shell dead - restarting session"
  pkill -f "gnome-session" 2>/dev/null; pkill -f "gnome-shell" 2>/dev/null; sleep 2
  export XDG_CURRENT_DESKTOP=GNOME XDG_SESSION_TYPE=x11 XDG_SESSION_DESKTOP=gnome
  export QT_X11_NO_MITSHM=1 LIBGL_ALWAYS_SOFTWARE=1 GSK_RENDERER=cairo GDK_BACKEND=x11 MESA_GL_VERSION_OVERRIDE=3.3
  [ -f /tmp/dbus.env ] && source /tmp/dbus.env
  setsid nohup env DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket gnome-session --session=gnome > /tmp/gnome.log 2>&1 < /dev/null &
  echo "session restarted"
fi
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
  timeout 15 pactl load-module module-null-sink sink_name=virtual_sink 2>/dev/null
  timeout 15 pactl set-default-sink virtual_sink 2>/dev/null
  timeout 15 pactl set-default-source virtual_sink.monitor 2>/dev/null
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