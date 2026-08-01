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
printf "DBUS_SESSION_BUS_ADDRESS='%s';\nexport DBUS_SESSION_BUS_ADDRESS;\nDBUS_SESSION_BUS_PID=%s;\n" "$DBUS_SESSION_BUS_ADDRESS" "$DBUS_SESSION_BUS_PID" > /tmp/dbus.env

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

echo "=== Xvnc :1 ==="
pkill -f "Xvnc :1" 2>/dev/null
sleep 2
Xvnc :1 -geometry 1920x1080 -depth 24 -SecurityTypes None -localhost yes -desktop arch-macos &
sleep 3

echo "=== xfce desktop (macOS look) ==="
sudo pacman -S --noconfirm --needed \
  xfce4 \
  xfce4-whiskermenu-plugin xfce4-pulseaudio-plugin xfce4-clipman-plugin xfce4-notifyd \
  plank papirus-icon-theme \
  xorg-xwd xorg-xwininfo imagemagick git 2>&1 | tail -3

mkdir -p /home/codespace/.themes /home/codespace/.icons /home/codespace/Pictures

if [ ! -d /tmp/WhiteSur-gtk-theme ]; then
  git clone --depth 1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git /tmp/WhiteSur-gtk-theme
fi
if [ ! -d /tmp/WhiteSur-icon-theme ]; then
  git clone --depth 1 https://github.com/vinceliuice/WhiteSur-icon-theme.git /tmp/WhiteSur-icon-theme
fi
if [ ! -d /tmp/WhiteSur-wallpapers ]; then
  git clone --depth 1 https://github.com/vinceliuice/WhiteSur-wallpapers.git /tmp/WhiteSur-wallpapers
fi

cd /home/codespace/.themes
tar -xJf /tmp/WhiteSur-gtk-theme/release/WhiteSur-Light.tar.xz
cd /tmp/WhiteSur-icon-theme && ./install.sh -d /home/codespace/.icons 2>&1 | tail -2
cp /tmp/WhiteSur-wallpapers/1080p/WhiteSur.jpg /home/codespace/Pictures/wallpaper.jpg

export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_TYPE=x11
export XDG_SESSION_DESKTOP=xfce
nohup xfce4-session > /tmp/xfce.log 2>&1 &
sleep 12

echo "=== theme + wallpaper + no panels ==="
xfconf-query -c xsettings -p /Net/ThemeName -s "WhiteSur-Light"
xfconf-query -c xsettings -p /Net/IconThemeName -s "WhiteSur-light"
xfconf-query -c xfwm4 -p /general/theme -s "WhiteSur-Light"
xfconf-query -c xfwm4 -p /general/button_layout -s "HMC"

xfce4-panel -q 2>/dev/null
xfconf-query -c xfce4-panel -p /panels -s "" --create -t string
for p in $(xfconf-query -c xfce4-panel -l 2>/dev/null | grep -E "^/panels/panel"); do
  xfconf-query -c xfce4-panel -p "$p" -r
done

B=/backdrop/screen0/monitorVNC-0/workspace0
xfconf-query -c xfce4-desktop -p "$B/last-image" -s /home/codespace/Pictures/wallpaper.jpg --create -t string
xfconf-query -c xfce4-desktop -p "$B/image-style" -s 5 --create -t int
xfconf-query -c xfce4-desktop -p "$B/image-show" -s true --create -t bool

nohup plank > /tmp/plank.log 2>&1 &

echo "=== google chrome ==="
if [ ! -x /opt/google/chrome/chrome ]; then
  cd /tmp
  curl -fL -o chrome.deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
  mkdir -p /tmp/chrome_extract && cd /tmp/chrome_extract
  ar x /tmp/chrome.deb
  tar -xf data.tar.xz
  sudo rm -rf /opt/google/chrome
  sudo cp -a /tmp/chrome_extract/opt/google/chrome /opt/google/
  sudo chmod 755 /opt/google/chrome/chrome
  sudo chmod a+rX -R /opt/google/chrome
  sudo ln -sf /opt/google/chrome/chrome /usr/local/bin/google-chrome
  sudo ln -sf /opt/google/chrome/chrome /usr/local/bin/google-chrome-stable
fi
sudo cp /tmp/chrome_extract/usr/share/applications/google-chrome.desktop /usr/share/applications/ 2>/dev/null
sudo sed -i 's|^Exec=.*|Exec=/usr/bin/google-chrome-stable --no-sandbox %U|' /usr/share/applications/google-chrome.desktop
sudo mkdir -p /usr/share/icons/hicolor/128x128/apps
sudo cp /tmp/chrome_extract/opt/google/chrome/product_logo_256.png /usr/share/icons/hicolor/128x128/apps/google-chrome.png 2>/dev/null
mkdir -p /home/codespace/.config/plank/dock1/launchers
printf '[PlankDockItemPreferences]\nLauncher=file:///usr/share/applications/google-chrome.desktop\n' > /home/codespace/.config/plank/dock1/launchers/chrome.dockitem

echo "=== noVNC (browser access) ==="
if [ ! -d /tmp/noVNC ]; then
  git clone --depth 1 https://github.com/novnc/noVNC.git /tmp/noVNC
fi
if [ ! -x /tmp/venv/bin/websockify ]; then
  python -m venv /tmp/venv
  /tmp/venv/bin/pip install --quiet websockify
fi
pkill -f websockify 2>/dev/null
nohup /tmp/venv/bin/websockify --web /tmp/noVNC 6080 localhost:5901 > /tmp/novnc.log 2>&1 &

sleep 5
echo "=== verify ==="
ps -o pid,cmd -C Xvnc,pipewire,wireplumber,rustdesk 2>/dev/null
ps -ef | grep -E "xfce4-session|xfwm4|xfdesktop|plank" | grep -v grep
pactl list short sinks
echo "=== starting rustdesk ==="
nohup rustdesk --server > /tmp/rustdesk-server.log 2>&1 &
nohup rustdesk --tray > /tmp/rustdesk-tray.log 2>&1 &
echo "SETUP_DONE"
