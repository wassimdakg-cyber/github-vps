FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386 \
    && apt-get update && apt-get install -y --no-install-recommends \
    sudo git curl wget tar xz-utils unzip gzip procps ca-certificates gnupg \
    tigervnc-standalone-server tigervnc-common x11-utils x11-xserver-utils x11-xkb-utils xterm \
    openssh-server \
    gnome-shell gnome-session gnome-terminal nautilus gedit gnome-settings-daemon \
    gnome-control-center gsettings-desktop-schemas \
    gnome-software gnome-software-plugin-flatpak flatpak \
    wine wine64 winbind \
    pipewire pipewire-pulse wireplumber pulseaudio-utils \
    ffmpeg imagemagick \
    python3 python3-pip python3-venv \
    fonts-dejavu fonts-liberation \
    dbus dbus-x11 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN ssh-keygen -A \
    && mkdir -p /run/sshd \
    && sed -i -E 's/^#?Port .*/Port 2222/' /etc/ssh/sshd_config \
    && sed -i -E 's/^#?(PermitRootLogin).*/\1 yes/' /etc/ssh/sshd_config \
    && sed -i -E 's/^#?(UsePAM).*/\1 yes/' /etc/ssh/sshd_config \
    && sed -i -E 's/^#?(PasswordAuthentication).*/\1 no/' /etc/ssh/sshd_config

RUN useradd -m -s /bin/bash codespace \
    && echo "codespace ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/codespace \
    && chmod 440 /etc/sudoers.d/codespace

ENV DISPLAY=:1
WORKDIR /home/codespace