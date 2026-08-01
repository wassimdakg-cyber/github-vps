FROM archlinux:latest

RUN pacman -Syu --noconfirm --needed base base-devel git sudo curl wget \
    xorg-server xorg-xinit xorg-xrandr xorg-xrdb tigervnc \
    xfce4 xfce4-whiskermenu-plugin xfce4-pulseaudio-plugin xfce4-clipman-plugin xfce4-notifyd \
    plank papirus-icon-theme \
    xorg-xwd xorg-xwininfo imagemagick \
    pipewire pipewire-pulse wireplumber libpulse \
    python python-pip xterm \
    gtk3 gtk4 ffmpeg \
    networkmanager \
    dbus \
    && rm -rf /var/cache/pacman/pkg

RUN useradd -m -s /bin/bash codespace \
    && echo "codespace ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/codespace \
    && chmod 440 /etc/sudoers.d/codespace

ENV DISPLAY=:1
USER codespace
WORKDIR /home/codespace
