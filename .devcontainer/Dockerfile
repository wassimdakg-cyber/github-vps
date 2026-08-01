FROM archlinux:latest

RUN pacman -Syu --noconfirm --needed base base-devel git sudo curl wget \
    xorg-server xorg-xinit xorg-xrandr xorg-xrdb tigervnc \
    gnome-shell gnome-session gnome-terminal gdm gnome-control-center \
    gsettings-desktop-schemas gnome-settings-daemon \
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
