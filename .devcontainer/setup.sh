#!/bin/bash
set -x
export XDG_RUNTIME_DIR=/tmp/runtime-codespace
export PULSE_SERVER=unix:/tmp/runtime-codespace/pulse/native
export DISPLAY=:1
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR

echo "=== starting dbus ==="
eval "$(dbus-launch --sh-syntax)"
export DBUS_SESSION_BUS_ADDRESS

echo "=== audio stack ==="
pipewire &
pipewire-pulse &
wireplumber &
sleep 4
pactl load-module module-null-sink sink_name=virtual_sink
pactl set-default-sink virtual_sink
pactl set-default-source virtual_sink.monitor

echo "=== rustdesk (arch pkg) ==="
if ! command -v rustdesk >/dev/null; then
  cd /tmp
  curl -fL -o rustdesk.pkg.tar.zst "https://github.com/rustdesk/rustdesk/releases/download/1.4.9/rustdesk-1.4.9-0-x86_64.pkg.tar.zst"
  ls -la rustdesk.pkg.tar.zst
  sudo pacman -U --noconfirm /tmp/rustdesk.pkg.tar.zst || echo "install failed"
fi

echo "=== Xvnc :1 + gnome-shell ==="
pkill -f "Xvnc :1" 2>/dev/null
sleep 2
Xvnc :1 -geometry 1920x1080 -depth 24 -SecurityTypes None -localhost yes -desktop arch-macos &
sleep 3
export XDG_CURRENT_DESKTOP=GNOME
export XDG_SESSION_TYPE=x11
export XDG_SESSION_DESKTOP=gnome
export XDG_SESSION_CLASS=user
nohup gnome-shell --display=:1 --no-wayland > /tmp/gnome.log 2>&1 &

sleep 8
echo "=== verify ==="
ps -o pid,cmd -C Xvnc,gnome-shell,pipewire,wireplumber,rustdesk 2>/dev/null
pactl list short sinks
echo "=== starting rustdesk ==="
nohup rustdesk --server > /tmp/rustdesk-server.log 2>&1 &
nohup rustdesk --tray > /tmp/rustdesk-tray.log 2>&1 &
echo "SETUP_DONE"
