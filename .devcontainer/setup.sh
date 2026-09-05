#!/bin/bash
set -x
exec 9>/tmp/setup.lock
if ! flock -n 9; then
  echo "another setup.sh already running, exiting"
  exit 0
fi
export XDG_RUNTIME_DIR=/tmp/runtime-codespace
export PULSE_SERVER=unix:/tmp/runtime-codespace/pulse/native
export DISPLAY=:1
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR

echo "=== dbus ==="
eval "$(dbus-launch --sh-syntax)"
export DBUS_SESSION_BUS_ADDRESS
printf "DBUS_SESSION_BUS_ADDRESS='%s';\nexport DBUS_SESSION_BUS_ADDRESS;\nDBUS_SESSION_BUS_PID=%s;\n" "$DBUS_SESSION_BUS_ADDRESS" "$DBUS_SESSION_BUS_PID" > /tmp/dbus.env
pgrep -x dbus-daemon >/dev/null || sudo dbus-daemon --system --fork 2>&1 || true
sudo mkdir -p /var/lib/flatpak/repo
sudo ostree init --repo=/var/lib/flatpak/repo --mode=bare-user-only 2>/dev/null || echo "flatpak system repo already ok"

echo "=== audio stack ==="
if ! command -v pactl >/dev/null 2>&1; then
  timeout 90 sudo apt-get install -y pulseaudio-utils 2>/dev/null || echo "pulseaudio-utils install failed"
fi
setsid nohup pipewire > /tmp/pipewire.log 2>&1 < /dev/null &
setsid nohup pipewire-pulse > /tmp/pipewire.log 2>&1 < /dev/null &
setsid nohup wireplumber > /tmp/pipewire.log 2>&1 < /dev/null &
sleep 4
timeout 15 pactl load-module module-null-sink sink_name=virtual_sink
timeout 15 pactl set-default-sink virtual_sink
timeout 15 pactl set-default-source virtual_sink.monitor

echo "=== flatpak + flathub ==="
mkdir -p /home/codespace/.local/share/flatpak/repo
timeout 120 flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>&1 || echo "flathub add failed (will retry)"

echo "=== firefox via flatpak ==="
if ! flatpak --user info org.mozilla.firefox >/dev/null 2>&1; then
  timeout 300 flatpak --user install -y --noninteractive flathub org.mozilla.firefox 2>&1 | tail -3 || echo "firefox flatpak install failed"
fi

echo "=== rustdesk (ubuntu deb) ==="
if ! command -v rustdesk >/dev/null; then
  cd /tmp
  timeout 120 curl -fL -o rustdesk.deb "https://github.com/rustdesk/rustdesk/releases/download/1.4.9/rustdesk-1.4.9-x86_64.deb" || echo "rustdesk download failed"
  timeout 180 sudo apt-get install -y /tmp/rustdesk.deb 2>&1 | tail -3 || \
  (sudo dpkg -i /tmp/rustdesk.deb 2>&1 | tail -2; timeout 180 sudo apt-get -f -y install 2>&1 | tail -2) || echo "rustdesk install failed"
fi

echo "=== Xvnc :1 ==="
pkill -f "Xvnc :1" 2>/dev/null
sleep 2
setsid nohup Xvnc :1 -geometry 1920x1080 -depth 24 -SecurityTypes None -localhost yes -desktop ubuntu-gnome > /tmp/xvnc.log 2>&1 < /dev/null &
sleep 3

echo "=== GNOME (X11 session) ==="
export XDG_CURRENT_DESKTOP=GNOME
export XDG_SESSION_TYPE=x11
export XDG_SESSION_DESKTOP=gnome
export XDG_CURRENT_DESKTOP=GNOME-Classic:GNOME
export QT_X11_NO_MITSHM=1
export LIBGL_ALWAYS_SOFTWARE=1
export COLORTERM=truecolor
setsid nohup dbus-run-session -- gnome-session --session=gnome > /tmp/gnome.log 2>&1 < /dev/null &
sleep 30

echo "=== google chrome (ubuntu deb) ==="
if [ ! -x /usr/bin/google-chrome-stable ]; then
  cd /tmp
  timeout 120 curl -fL -o chrome.deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" || echo "chrome download failed"
  timeout 180 sudo apt-get install -y /tmp/chrome.deb 2>&1 | tail -3 || \
  (sudo dpkg -i /tmp/chrome.deb 2>&1 | tail -2; timeout 180 sudo apt-get -f -y install 2>&1 | tail -2) || echo "chrome install failed"
fi
sudo sed -i 's|^Exec=.*|Exec=/usr/bin/google-chrome-stable --no-sandbox %U|' /usr/share/applications/google-chrome.desktop 2>/dev/null || true

echo "=== noVNC (browser access) ==="
if [ ! -d /tmp/noVNC ]; then
  git clone --depth 1 https://github.com/novnc/noVNC.git /tmp/noVNC 2>&1 | tail -1
fi
if [ ! -x /tmp/venv/bin/websockify ]; then
  (python3 -m venv /tmp/venv && /tmp/venv/bin/pip install --quiet websockify) \
    || pip install --quiet --break-system-packages websockify \
    || sudo apt-get install -y websockify \
    || echo "websockify install failed"
fi
pkill -f websockify 2>/dev/null
WEBSOCKIFY="$(command -v /tmp/venv/bin/websockify || command -v websockify || echo /tmp/venv/bin/websockify)"
setsid nohup $WEBSOCKIFY --web /tmp/noVNC 6080 localhost:5901 > /tmp/novnc.log 2>&1 < /dev/null &

echo "=== ssh key (append, never clobber agent keys) ==="
sudo mkdir -p /home/codespace/.ssh
sudo grep -q 'codespaces.auto' /home/codespace/.ssh/authorized_keys 2>/dev/null \
  || echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKDa0sIqTsn5lnJfODhG9HtFNdplDjakEsSSdcTS/bjP" | sudo tee -a /home/codespace/.ssh/authorized_keys
sudo chown -R codespace:codespace /home/codespace/.ssh
sudo chmod 700 /home/codespace/.ssh
sudo chmod 600 /home/codespace/.ssh/authorized_keys
ss -tlnp 2>/dev/null | grep 2222 || echo "sshd-not-listening"

sleep 5
echo "=== verify ==="
ps -o pid,cmd -C Xvnc,pipewire,wireplumber,rustdesk 2>/dev/null
ps -ef | grep -E "gnome-shell|startplasma" | grep -v grep
pactl list short sinks
echo "=== starting rustdesk ==="
setsid nohup rustdesk --server > /tmp/rustdesk-server.log 2>&1 < /dev/null &
setsid nohup rustdesk --tray > /tmp/rustdesk-tray.log 2>&1 < /dev/null &
echo "SETUP_DONE"