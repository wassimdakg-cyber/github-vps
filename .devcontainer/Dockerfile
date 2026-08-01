FROM fedora:43

RUN dnf -y install \
    sudo git curl wget tar xz unzip gzip procps-ng which ca-certificates \
    tigervnc-server xrandr \
    openssh-server \
    plasma-workspace plasma-workspace-x11 plasma-workspace-wallpapers plasma-desktop kwin kwin-x11 plasma-nm \
    konsole dolphin systemsettings kde-gtk-config \
    breeze-icon-theme adwaita-icon-theme fedora-logos \
    mesa-dri-drivers \
    pipewire pipewire-pulse wireplumber pipewire-alsa pulseaudio-utils \
    ffmpeg ImageMagick \
    python3 python3-pip \
    dejavu-sans-fonts liberation-fonts \
    dbus dbus-x11 dbus-tools xterm \
    NetworkManager \
    && ssh-keygen -A \
    && mkdir -p /run/sshd \
    && sed -i -E 's/^#?Port .*/Port 2222/' /etc/ssh/sshd_config \
    && sed -i -E 's/^#?(PermitRootLogin).*/\1 yes/' /etc/ssh/sshd_config \
    && sed -i -E 's/^#?(UsePAM).*/\1 yes/' /etc/ssh/sshd_config \
    && sed -i -E 's/^#?(PasswordAuthentication).*/\1 no/' /etc/ssh/sshd_config \
    && dnf clean all

RUN useradd -m -s /bin/bash codespace \
    && echo "codespace ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/codespace \
    && chmod 440 /etc/sudoers.d/codespace

ENV DISPLAY=:1
WORKDIR /home/codespace
