#!/usr/bin/env bash
# Build an Ubuntu 24.04 arm64 root filesystem for the DE25-Nano, with ROS 2 Jazzy.
#
# Terasic's own image is Ubuntu 22.04.3. This one matches the host and the KV260
# course instead: 24.04 + Jazzy. It runs in an emulated arm64 container (needs
# qemu-user-static binfmt on the host), then exports the container as a tarball.
# The kernel modules from build-boot.sh are added later, when the SD image is made.
#
# Output: build/de25nano/os/rootfs/rootfs-noble-jazzy.tar
# Usage:  boards/de25nano/os/build-rootfs.sh
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
OUT=$ROOT/build/de25nano/os/rootfs
NAME=de25-rootfs-build
mkdir -p "$OUT"
docker rm -f "$NAME" >/dev/null 2>&1 || true

docker run -i --name "$NAME" --platform linux/arm64 ubuntu:24.04 bash -s <<'EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8
echo "==> Base system"
apt-get update -q >/dev/null
apt-get install -y -q --no-install-recommends \
    systemd systemd-sysv systemd-resolved udev dbus kmod sudo openssh-server \
    network-manager iputils-ping net-tools ethtool locales tzdata ca-certificates \
    curl gnupg vim-tiny less bash-completion usbutils i2c-tools gpiod \
    device-tree-compiler python3 python3-numpy fdisk >/dev/null
locale-gen en_US.UTF-8 >/dev/null

echo "==> ROS 2 Jazzy (ros-base)"
curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [arch=arm64 signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu noble main" \
    > /etc/apt/sources.list.d/ros2.list
apt-get update -q >/dev/null
apt-get install -y -q --no-install-recommends ros-jazzy-ros-base >/dev/null
echo "source /opt/ros/jazzy/setup.bash" >> /etc/bash.bashrc

echo "==> Board settings"
echo de25-nano > /etc/hostname
printf '127.0.0.1 localhost\n127.0.1.1 de25-nano\n' > /etc/hosts
useradd -m -s /bin/bash -G sudo,adm,dialout,video,i2c de25 2>/dev/null || useradd -m -s /bin/bash -G sudo,adm,dialout,video de25
echo de25:de25 | chpasswd && passwd -e de25 >/dev/null   # must change on first login
mkdir -p /etc/NetworkManager/conf.d
printf '[keyfile]\nunmanaged-devices=none\n' > /etc/NetworkManager/conf.d/allow-ethernet.conf
systemctl enable ssh NetworkManager systemd-resolved serial-getty@ttyS0 >/dev/null 2>&1 || true
apt-get clean && rm -rf /var/lib/apt/lists/*

echo "==> Sizes"
du -sh / --exclude=/proc --exclude=/sys 2>/dev/null | tail -1
du -sh /opt/ros/jazzy
dpkg -l | grep -c '^ii'
EOF

echo "==> Exporting"
docker export "$NAME" -o "$OUT/rootfs-noble-jazzy.tar"
docker rm "$NAME" >/dev/null
ls -lh "$OUT/rootfs-noble-jazzy.tar"
