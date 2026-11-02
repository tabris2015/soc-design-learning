#!/usr/bin/env bash
# Assemble a bootable DE25-Nano microSD image from build-boot.sh and build-rootfs.sh
# outputs. Same layout as Terasic's guide (FAT32 boot partition + Linux rootfs), but
# built without root or loop devices: mtools fills the FAT image, mke2fs -d fills the
# ext4 image, and sfdisk + dd stitch them into one file. The SPL and FPGA image stay
# in the board's QSPI flash and are not touched.
#
# Output: build/de25nano/os/sd/de25-nano-noble-jazzy.img
# Usage:  boards/de25nano/os/build-sdimage.sh
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
BOOT=$ROOT/build/de25nano/os/boot/out
ROOTFS=$ROOT/build/de25nano/os/rootfs/rootfs-noble-jazzy.tar
OUT=$ROOT/build/de25nano/os/sd
for f in "$BOOT/u-boot.itb" "$BOOT/Image" "$BOOT/socfpga_agilex5_de25_nano.dtb" "$ROOTFS"; do
    [ -e "$f" ] || { echo "missing $f, run build-boot.sh and build-rootfs.sh first" >&2; exit 1; }
done
mkdir -p "$OUT"
docker pull -q --platform linux/amd64 ubuntu:noble >/dev/null

docker run --rm -i --platform linux/amd64 \
    -v "$BOOT:/boot-out:ro" -v "$ROOTFS:/rootfs.tar:ro" -v "$OUT:/out" \
    -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
    ubuntu:noble bash -s <<'EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -q >/dev/null
apt-get install -y -q --no-install-recommends dosfstools mtools e2fsprogs fdisk u-boot-tools device-tree-compiler >/dev/null
W=/tmp/sd; mkdir -p $W && cd $W

echo "==> Boot script"
# Terasic's uboot.txt, with 'bridge enable' so the HPS can reach FPGA peripherals.
cat > uboot.txt <<'TXT'
echo "Trying to boot Linux from device ${target}";
if test ${target} = "mmc0"; then
        bridge enable;
        echo "Found kernel in mmc0";
        mmc rescan;
        fatload mmc 0:1 ${kernel_addr_r} Image;
        fatload mmc 0:1 ${fdt_addr_r} socfpga_agilex5_de25_nano.dtb;
        setenv bootargs "console=ttyS0,115200 root=${mmcroot} rw rootwait";
        booti ${kernel_addr_r} - ${fdt_addr_r};
        exit;
fi
TXT
cat > uboot_script.its <<'ITS'
/dts-v1/;
/ {
    description = "U-Boot boot script";
    #address-cells = <1>;
    images {
        default = "script";
        script {
            data = /incbin/("./uboot.txt");
            type = "script";
            compression = "none";
        };
    };
};
ITS
mkimage -f uboot_script.its boot.scr.uimg >/dev/null

echo "==> FAT32 boot partition (500 MiB)"
mkfs.vfat -F 32 -n BOOT -C fat.img $((500*1024)) >/dev/null
mcopy -i fat.img /boot-out/u-boot.itb /boot-out/Image /boot-out/socfpga_agilex5_de25_nano.dtb boot.scr.uimg ::
mdir -i fat.img ::

echo "==> ext4 rootfs partition (5000 MiB)"
mkdir rootfs && tar -xpf /rootfs.tar -C rootfs --exclude='./dev/*' --exclude='./proc/*' --exclude='./sys/*'
cp -a /boot-out/modules/lib/modules rootfs/lib/
chown -R 0:0 rootfs/lib/modules   # build outputs are owned by the host user
rm -f rootfs/.dockerenv
printf '/dev/mmcblk0p2  /      ext4  defaults,noatime  0 1\n/dev/mmcblk0p1  /boot  vfat  defaults          0 2\n' > rootfs/etc/fstab
mkdir -p rootfs/boot
mkfs.ext4 -q -L rootfs -d rootfs root.img 5000M

echo "==> Partition table and image"
IMG=/out/de25-nano-noble-jazzy.img
rm -f $IMG && truncate -s 5600M $IMG
sfdisk -q $IMG <<SF
label: dos
start=2048, size=$((500*2048)), type=b
start=$((2048 + 500*2048)), size=$((5000*2048)), type=83
SF
dd if=fat.img of=$IMG bs=1M seek=1 conv=notrunc,sparse status=none
dd if=root.img of=$IMG bs=1M seek=$((1 + 500)) conv=notrunc,sparse status=none
sfdisk -l $IMG
chown "$HOST_UID:$HOST_GID" $IMG
EOF
ls -lsh "$OUT/de25-nano-noble-jazzy.img"
echo
echo "Write it with:  sudo dd if=$OUT/de25-nano-noble-jazzy.img of=/dev/sdX bs=4M conv=fsync status=progress"
