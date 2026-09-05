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
if [ ! -S /run/dbus/system_bus_socket ]; then
  sudo mkdir -p /run/dbus
  sudo dbus-daemon --system --fork 2>&1 || echo "system dbus failed"
fi
sleep 1

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

echo "=== flatpak + flathub (flatpak inits repos itself) ==="
rm -rf /home/codespace/.local/share/flatpak/repo
timeout 120 flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>&1 || echo "flathub add failed (will retry)"

echo "=== rustdesk (ubuntu deb) ==="
if ! command -v rustdesk >/dev/null; then
  cd /tmp
  timeout 240 curl -fL -o rustdesk.deb "https://github.com/rustdesk/rustdesk/releases/download/1.4.9/rustdesk-1.4.9-x86_64.deb" || echo "rustdesk download failed"
  timeout 300 sudo apt-get install -y /tmp/rustdesk.deb 2>&1 | tail -3 || \
  (sudo dpkg -i /tmp/rustdesk.deb 2>&1 | tail -2; timeout 300 sudo apt-get -f -y install 2>&1 | tail -2) || echo "rustdesk install failed"
fi

echo "=== Xvnc :1 ==="
pkill -f "Xvnc :1" 2>/dev/null
sleep 2
rm -f /tmp/.X1-lock
rm -f /tmp/.X11-unix/X1
setsid nohup Xvnc :1 -geometry 1920x1080 -depth 24 -SecurityTypes None -localhost yes -desktop ubuntu-gnome > /tmp/xvnc.log 2>&1 < /dev/null &
sleep 5
if ! pgrep -f "Xvnc :1" >/dev/null 2>&1; then
  echo "Xvnc failed to start, retrying after cleanup"
  rm -f /tmp/.X1-lock
  rm -f /tmp/.X11-unix/X1
  setsid nohup Xvnc :1 -geometry 1920x1080 -depth 24 -SecurityTypes None -localhost yes -desktop ubuntu-gnome > /tmp/xvnc.log 2>&1 < /dev/null &
  sleep 5
fi

echo "=== GNOME (X11 session) ==="
echo "hiding systemd marker so gnome-shell uses non-systemd login manager"
sudo rm -rf /run/systemd/seats 2>/dev/null || true
echo "pruning crash-prone settings-daemon components from session"
sudo sed -i 's|^RequiredComponents=.*|RequiredComponents=org.gnome.Shell;org.gnome.SettingsDaemon.A11ySettings;org.gnome.SettingsDaemon.Color;org.gnome.SettingsDaemon.Keyboard;org.gnome.SettingsDaemon.MediaKeys;org.gnome.SettingsDaemon.PrintNotifications;org.gnome.SettingsDaemon.Sound;org.gnome.SettingsDaemon.Wacom;|' /usr/share/gnome-session/sessions/gnome.session
source /tmp/dbus.env
export XDG_CURRENT_DESKTOP=GNOME
export XDG_SESSION_TYPE=x11
export XDG_SESSION_DESKTOP=gnome
export QT_X11_NO_MITSHM=1
export LIBGL_ALWAYS_SOFTWARE=1
export COLORTERM=truecolor
export GSK_RENDERER=cairo
export GDK_BACKEND=x11
export MESA_GL_VERSION_OVERRIDE=3.3
pkill -f "gnome-session" 2>/dev/null
pkill -f "gnome-shell" 2>/dev/null
sleep 2
setsid nohup gnome-session --session=gnome > /tmp/gnome.log 2>&1 < /dev/null &
sleep 30

echo "=== google chrome (ubuntu deb) ==="
if [ ! -x /usr/bin/google-chrome-stable ]; then
  cd /tmp
  timeout 240 curl -fL -o chrome.deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" || echo "chrome download failed"
  timeout 300 sudo apt-get install -y /tmp/chrome.deb 2>&1 | tail -3 || \
  (sudo dpkg -i /tmp/chrome.deb 2>&1 | tail -2; timeout 300 sudo apt-get -f -y install 2>&1 | tail -2) || echo "chrome install failed"
fi
sudo sed -i 's|^Exec=.*|Exec=/usr/bin/google-chrome-stable --no-sandbox %U|' /usr/share/applications/google-chrome.desktop 2>/dev/null || true

echo "=== firefox (mozilla tarball - flatpak is blocked by userns ban) ==="
if [ ! -x /opt/firefox/firefox/firefox ]; then
  cd /tmp
  timeout 500 curl -fL -o ff.tar.zst "https://download.mozilla.org/?product=firefox-latest&os=linux64&lang=en-US" || echo "firefox download failed"
  sudo rm -rf /opt/firefox
  sudo mkdir -p /opt/firefox
  sudo tar --zstd -xf /tmp/ff.tar.zst -C /opt/firefox 2>&1 | tail -2
  sudo chown -R codespace:codespace /opt/firefox
fi
mkdir -p /home/codespace/.local/share/applications
cat > /home/codespace/.local/share/applications/firefox.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Firefox
Comment=Web Browser
Exec=/opt/firefox/firefox/firefox %U
Icon=/opt/firefox/firefox/browser/chrome/icons/default/default128.png
Terminal=false
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;
EOF

echo "=== TL Legacy launcher (native jar - flatpak blocked by userns ban) ==="
if [ ! -s /home/codespace/.local/share/TLauncher/LegacyLauncher.jar ]; then
  mkdir -p /home/codespace/.local/share/TLauncher
  cd /home/codespace/.local/share/TLauncher
  timeout 300 curl -fL -o LegacyLauncher.jar "https://dl.llaun.ch/legacy/bootstrap" || echo "TL download failed"
fi
cat > /home/codespace/.local/share/applications/tlauncher.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=TL Legacy
Comment=Minecraft Launcher
Exec=sh -c 'cd /home/codespace/.local/share/TLauncher && java -jar LegacyLauncher.jar'
Terminal=false
Categories=Game;
EOF

echo "=== noVNC (browser access) ==="
if [ ! -d /tmp/noVNC ]; then
  git clone --depth 1 https://github.com/novnc/noVNC.git /tmp/noVNC 2>&1 | tail -1
fi
if [ ! -x /tmp/venv/bin/websockify ]; then
  (python3 -m venv /tmp/venv 2>/dev/null && /tmp/venv/bin/pip install --quiet websockify 2>/dev/null) \
    || pip install --quiet --break-system-packages websockify 2>/dev/null \
    || sudo apt-get install -y websockify 2>/dev/null \
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

echo "=== rustdesk launch ==="
pkill -f rustdesk 2>/dev/null
sleep 1
setsid nohup rustdesk --server > /tmp/rustdesk-server.log 2>&1 < /dev/null &
sleep 4
setsid nohup rustdesk --tray > /tmp/rustdesk-tray.log 2>&1 < /dev/null &

sleep 5
echo "=== verify ==="
ps -o pid,cmd -C Xvnc,pipewire,wireplumber 2>/dev/null
ps -ef | grep -E "gnome-shell|rustdesk" | grep -v grep
flatpak --user remotes
echo "--- ports ---"
bash -c 'echo > /dev/tcp/localhost/5901' 2>/dev/null && echo "5901 OPEN" || echo "5901 CLOSED"
bash -c 'echo > /dev/tcp/localhost/6080' 2>/dev/null && echo "6080 OPEN" || echo "6080 CLOSED"
echo "SETUP_DONE"