FROM fedora:43

RUN dnf -y install \
    sudo git curl wget tar xz unzip gzip procps-ng which ca-certificates \
    tigervnc-server xrandr \
    plasma-workspace plasma-workspace-x11 plasma-workspace-wallpapers plasma-desktop kwin kwin-x11 plasma-nm \
    konsole dolphin systemsettings kde-gtk-config \
    breeze-icon-theme adwaita-icon-theme fedora-logos \
    mesa-dri-drivers \
    pipewire pipewire-pulse wireplumber pipewire-alsa \
    ffmpeg ImageMagick \
    python3 python3-pip \
    dejavu-sans-fonts liberation-fonts \
    dbus dbus-x11 dbus-tools xterm \
    NetworkManager \
    && dnf clean all

RUN useradd -m -s /bin/bash codespace \
    && echo "codespace ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/codespace \
    && chmod 440 /etc/sudoers.d/codespace

ENV DISPLAY=:1
USER codespace
WORKDIR /home/codespace
