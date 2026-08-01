#!/bin/bash
set -x
export XDG_RUNTIME_DIR=/run/user/1000
export PULSE_SERVER=unix:/run/user/1000/pulse/native
export DISPLAY=:1
mkdir -p $XDG_RUNTIME_DIR
chown codespace:codespace $XDG_RUNTIME_DIR 2>/dev/null || true

echo "=== starting dbus ==="
dbus-launch --sh-syntax > /tmp/dbus.env
. /tmp/dbus.env

echo "=== audio stack ==="
pipewire &
pipewire-pulse &
wireplumber &
sleep 4
pactl load-module module-null-sink sink_name=virtual_sink
pactl set-default-sink virtual_sink
pactl set-default-source virtual_sink.monitor

echo "=== rustdesk (arch pkg) ==="
RUSTDESK_RPM=rustdesk-1.4.9-0-x86_64.pkg.tar.zst
if ! command -v rustdesk >/dev/null; then
  cd /tmp
  curl -fL -o rustdesk.pkg.tar.zst "https://github.com/rustdesk/rustdesk/releases/download/1.4.9/$RUSTDESK_RPM" || echo "download failed"
  ls -la rustdesk.pkg.tar.zst
  sudo pacman -U --noconfirm /tmp/rustdesk.pkg.tar.zst || echo "install failed"
fi

echo "=== Xvnc :1 + gnome ==="
pkill -f "Xvnc :1" 2>/dev/null
sleep 2
Xvnc :1 -geometry 1920x1080 -depth 24 -SecurityTypes None -localhost yes -desktop arch-macos &
sleep 3
export XDG_CURRENT_DESKTOP=GNOME
export XDG_SESSION_TYPE=x11
nohup gnome-session --session=gnome > /tmp/gnome.log 2>&1 &

sleep 8
echo "=== verify ==="
ps -o pid,cmd -C Xvnc,gnome-shell,pipewire,wireplumber,rustdesk 2>/dev/null
pactl list short sinks
echo "=== starting rustdesk ==="
nohup rustdesk --server > /tmp/rustdesk-server.log 2>&1 &
nohup rustdesk --tray > /tmp/rustdesk-tray.log 2>&1 &
echo "SETUP_DONE"
