#!/bin/bash
set -x
export XDG_RUNTIME_DIR=/tmp/runtime-codespace
export PULSE_SERVER=unix:/tmp/runtime-codespace/pulse/native
export DISPLAY=:1
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR

echo "=== dbus ==="
eval "$(dbus-launch --sh-syntax)"
export DBUS_SESSION_BUS_ADDRESS
printf "DBUS_SESSION_BUS_ADDRESS='%s';\nexport DBUS_SESSION_BUS_ADDRESS;\nDBUS_SESSION_BUS_PID=%s;\n" "$DBUS_SESSION_BUS_ADDRESS" "$DBUS_SESSION_BUS_PID" > /tmp/dbus.env

echo "=== audio stack ==="
pipewire &
pipewire-pulse &
wireplumber &
sleep 4
pactl load-module module-null-sink sink_name=virtual_sink
pactl set-default-sink virtual_sink
pactl set-default-source virtual_sink.monitor

echo "=== rustdesk (fedora rpm) ==="
if ! command -v rustdesk >/dev/null; then
  cd /tmp
  curl -fL -o rustdesk.rpm "https://github.com/rustdesk/rustdesk/releases/download/1.4.9/rustdesk-1.4.9-0.x86_64.rpm"
  sudo dnf install -y /tmp/rustdesk.rpm || echo "rustdesk rpm failed"
fi

echo "=== Xvnc :1 ==="
pkill -f "Xvnc :1" 2>/dev/null
sleep 2
Xvnc :1 -geometry 1920x1080 -depth 24 -SecurityTypes None -localhost yes -desktop fedora-kde &
sleep 3

echo "=== KDE Plasma (Fedora default look) ==="
export XDG_CURRENT_DESKTOP=KDE
export XDG_SESSION_TYPE=x11
export XDG_SESSION_DESKTOP=KDE
export QT_X11_NO_MITSHM=1
export LIBGL_ALWAYS_SOFTWARE=1
export KWIN_X11_NO_SYNC=1
nohup dbus-launch --exit-with-session startplasma-x11 > /tmp/kde.log 2>&1 &
sleep 25

echo "=== google chrome (fedora rpm) ==="
if [ ! -x /usr/bin/google-chrome-stable ]; then
  cd /tmp
  curl -fL -o chrome.rpm "https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm"
  sudo dnf install -y /tmp/chrome.rpm || echo "chrome rpm failed"
fi
sudo sed -i 's|^Exec=.*|Exec=/usr/bin/google-chrome-stable --no-sandbox %U|' /usr/share/applications/google-chrome.desktop

echo "=== noVNC (browser access) ==="
if [ ! -d /tmp/noVNC ]; then
  git clone --depth 1 https://github.com/novnc/noVNC.git /tmp/noVNC
fi
if [ ! -x /tmp/venv/bin/websockify ]; then
  python3 -m venv /tmp/venv
  /tmp/venv/bin/pip install --quiet websockify
fi
pkill -f websockify 2>/dev/null
nohup /tmp/venv/bin/websockify --web /tmp/noVNC 6080 localhost:5901 > /tmp/novnc.log 2>&1 &

sleep 5
echo "=== verify ==="
ps -o pid,cmd -C Xvnc,pipewire,wireplumber,rustdesk 2>/dev/null
ps -ef | grep -E "plasmashell|kwin_x11|startplasma" | grep -v grep
pactl list short sinks
echo "=== starting rustdesk ==="
nohup rustdesk --server > /tmp/rustdesk-server.log 2>&1 &
nohup rustdesk --tray > /tmp/rustdesk-tray.log 2>&1 &
echo "SETUP_DONE"
