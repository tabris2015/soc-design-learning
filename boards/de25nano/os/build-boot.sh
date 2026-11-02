#!/usr/bin/env bash
# Build the DE25-Nano boot stack from Terasic's public branches: ATF (bl31),
# U-Boot (u-boot.itb + SPL hex) and the Linux kernel (Image, modules, DTB).
#
# Runs inside an x86_64 Ubuntu 24.04 container, so the host needs only Docker.
# Outputs land in build/de25nano/os/boot/out. Quartus is not needed for any of this. It's only
# needed for FPGA bitstreams and the QSPI flash image.
#
# Kernel changes on top of Terasic's de25-nano.config, for the course:
#   ALTERA_MSGDMA=m        mSGDMA driver, for lesson 07's DMA
#   DMABUF_HEAPS(_CMA)=y   CMA dma-buf heap, for zero-copy buffers in lessons 20 and 24
#
# Usage:  boards/de25nano/os/build-boot.sh
set -euo pipefail

ATF_BRANCH=de25-nano-v2.12.0
UBOOT_BRANCH=de25-nano-v2025.01
LINUX_BRANCH=de25-nano-6.12.11-lts

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
WORK=$ROOT/build/de25nano/os/boot
mkdir -p "$WORK"

# Pull the x86_64 image explicitly. A local arm64 ubuntu:24.04 (from emulated tests)
# would otherwise run the whole build under emulation.
docker pull -q --platform linux/amd64 ubuntu:noble >/dev/null

docker run --rm -i --platform linux/amd64 \
    -v "$WORK:/w" -w /w \
    -e ATF_BRANCH="$ATF_BRANCH" -e UBOOT_BRANCH="$UBOOT_BRANCH" -e LINUX_BRANCH="$LINUX_BRANCH" \
    -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
    ubuntu:noble bash -s <<'EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
echo "==> Installing build dependencies"
apt-get update -q >/dev/null
apt-get install -y -q --no-install-recommends \
    build-essential gcc-aarch64-linux-gnu bison flex swig bc cpio rsync kmod git \
    ca-certificates python3 python3-dev python3-setuptools python3-pyelftools \
    libssl-dev libgnutls28-dev uuid-dev u-boot-tools device-tree-compiler >/dev/null
export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
aarch64-linux-gnu-gcc --version | head -1

fetch() {  # repo branch dir
    if [ -d "$3/.git" ]; then git -C "$3" fetch -q --depth 1 origin "$2" && git -C "$3" checkout -q FETCH_HEAD
    else git clone -q --depth 1 -b "$2" "https://github.com/terasic/$1" "$3"; fi
    echo "    $1 @ $2 $(git -C "$3" rev-parse --short HEAD)"
}
echo "==> Fetching Terasic sources"
fetch arm-trusted-firmware "$ATF_BRANCH" atf
fetch u-boot-socfpga "$UBOOT_BRANCH" u-boot
fetch linux-socfpga "$LINUX_BRANCH" linux

echo "==> Building ATF (bl31)"
make -C atf -j"$(nproc)" PLAT=agilex5 bl31 >atf.log 2>&1 || { tail -30 atf.log; exit 1; }

echo "==> Building U-Boot"
cd u-boot
make mrproper >/dev/null
make socfpga_agilex5_de25_nano_defconfig >/dev/null
ln -sf ../atf/build/agilex5/release/bl31.bin .
make -j"$(nproc)" >../uboot.log 2>&1 || { tail -30 ../uboot.log; exit 1; }
cd ..

echo "==> Building the kernel"
cd linux
cp de25-nano.config .config
./scripts/config -m ALTERA_MSGDMA -e DMABUF_HEAPS -e DMABUF_HEAPS_CMA -e DMABUF_HEAPS_SYSTEM
make olddefconfig >/dev/null
make -j"$(nproc)" Image modules dtbs >../linux.log 2>&1 || { tail -40 ../linux.log; exit 1; }
rm -rf ../out/modules && make -s modules_install INSTALL_MOD_PATH=../out/modules INSTALL_MOD_STRIP=1
cd ..

echo "==> Collecting outputs"
mkdir -p out
cp atf/build/agilex5/release/bl31.bin out/
cp u-boot/u-boot.itb u-boot/spl/u-boot-spl-dtb.hex out/
cp linux/arch/arm64/boot/Image linux/.config out/
cp linux/arch/arm64/boot/dts/intel/socfpga_agilex5_de25_nano.dtb out/
mv out/.config out/kernel.config
chown -R "$HOST_UID:$HOST_GID" /w
ls -la out
echo "kernel release: $(ls out/modules/lib/modules)"
EOF
echo
echo "Done. Boot files are in $WORK/out"
