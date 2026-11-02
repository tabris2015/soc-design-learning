#!/usr/bin/env bash
# Install PYNQ 3.1.2 on the KV260's Ubuntu 24.04, without Kria-PYNQ's installer.
#
# Kria-PYNQ's install.sh refuses anything but Ubuntu 22.04, and the PYNQ 3.0.1 it
# installs calls XRT's legacy xcl* API, which noble's XRT 2.18 no longer exports.
# PYNQ 3.1 talks to XRT through pyxrt instead. Nobody ships pyxrt for noble, so this
# script builds it against the installed XRT, then installs PYNQ 3.1.2, the KV260
# base overlay, the Composable Pipeline and JupyterLab on port 9090.
#
# Verified 2026-09-24 in an emulated arm64 ubuntu:24.04 container, up to the steps
# that need the board. Run ./check-pynq.sh on the board afterwards.
#
# DPU-PYNQ is not installed. Its runtime, vitis-ai-runtime 2.5, is in the noble PPA
# but depends on jammy libraries (libpython3.10, OpenCV 4.5) and will not install.
#
# On the board:  sudo ./install-pynq-noble.sh
set -euo pipefail

PYNQ_VERSION=3.1.2
XRT_VERSION=2.18.0                     # the pyxrt source below must match it
XRT_TAG=202420.2.18.0_Canonical        # the XRT tag Canonical's package was built from
KRIA_PYNQ_REV=8b975f43706490d179002900ff281480f7799ca5   # main, 2026-03-27
COMPOSABLE_REF=v1.1.0-dev              # the ref Kria-PYNQ's installer uses
BOARD=KV260

PYNQ_VENV=/usr/local/share/pynq-venv
SRC=/usr/local/src/kria-pynq
NB_USER=${SUDO_USER:-root}
NB_DIR=$(getent passwd "$NB_USER" | cut -d: -f6)/jupyter_notebooks

die()  { echo "!! $*" >&2; exit 1; }
warn() { echo "!! $*" >&2; }

[ "$EUID" -eq 0 ] || die "run as root: sudo $0"
[ "$(uname -m)" = aarch64 ] || die "this runs on the board, not the host (found $(uname -m))"
. /etc/os-release
[ "$VERSION_ID" = 24.04 ] || die "expects Ubuntu 24.04, found $VERSION_ID"

# Without these the script is running in a container: it installs everything
# and skips the steps that touch the kernel, the PL or systemd.
HAVE_SYSTEMD=0; [ -d /run/systemd/system ] && HAVE_SYSTEMD=1
HAVE_FPGA=0;    [ -e /sys/class/fpga_manager/fpga0 ] && HAVE_FPGA=1

export DEBIAN_FRONTEND=noninteractive
export BOARD                           # the kv260 package's setup.py reads it

echo "==> Adding the Xilinx PPAs"
# The PPA Kria-PYNQ uses (ubuntu-xilinx/updates) has no noble build.
# sdk carries xrt and xrt-dkms, gstreamer carries libdrm-xlnx-dev.
[ $HAVE_SYSTEMD = 1 ] && systemctl stop unattended-upgrades.service || true
apt-get update
apt-get install -y software-properties-common
add-apt-repository -y ppa:ubuntu-xilinx/sdk
add-apt-repository -y ppa:ubuntu-xilinx/gstreamer
apt-get update

echo "==> Installing packages"
apt-get install -y \
    build-essential pkg-config git curl wget file device-tree-compiler \
    python3-venv python3-dev python3-opencv \
    libboost-dev uuid-dev libdrm-xlnx-dev libcairo2-dev portaudio19-dev \
    libssl-dev libcurl4-openssl-dev graphviz i2c-tools \
    xrt

xrt_installed=$(dpkg-query -W -f='${Version}' xrt)
case "$xrt_installed" in
    "$XRT_VERSION"*) echo "OK: xrt $xrt_installed" ;;
    *) die "pyxrt is pinned to XRT $XRT_VERSION but xrt $xrt_installed is installed; update XRT_TAG" ;;
esac

# zocl is XRT's kernel driver. Canonical's Kria kernel doesn't ship it, so xrt-dkms
# compiles it against the running kernel's headers. Verified 2026-09-28 against
# 6.8.0-1036-xilinx in an emulated container. modinfo also finds a built-in zocl.
if modinfo zocl >/dev/null 2>&1; then
    echo "OK: zocl driver available"
elif [ $HAVE_FPGA = 1 ]; then
    echo "==> Building zocl with xrt-dkms for $(uname -r)"
    apt-get install -y "linux-headers-$(uname -r)" xrt-dkms
    modinfo zocl >/dev/null 2>&1 && echo "OK: zocl built" || die "xrt-dkms did not produce zocl for $(uname -r)"
else
    warn "not on a board, so skipping xrt-dkms (it builds against the running kernel)"
fi

echo "==> Fetching Kria-PYNQ at ${KRIA_PYNQ_REV:0:7}"
# Used for three things: libcma, the kv260 base overlay package, and the zocl
# device tree fragment. Its install.sh is not run.
if [ ! -d "$SRC/.git" ]; then
    git clone --quiet https://github.com/Xilinx/Kria-PYNQ.git "$SRC"
fi
git -C "$SRC" fetch --quiet origin
git -C "$SRC" checkout --quiet "$KRIA_PYNQ_REV"
git -C "$SRC" submodule update --init --depth 1 --quiet

echo "==> Installing libcma"
# PYNQ's HDMI helper includes libxlnk_cma.h, so this must come before pip install pynq.
# make -t marks the prebuilt libraries as current instead of rebuilding them.
make -C "$SRC/pynq/sdbuild/packages/libsds/libcma" -t
make -C "$SRC/pynq/sdbuild/packages/libsds/libcma" install

echo "==> Creating the venv at $PYNQ_VENV"
# --system-site-packages keeps apt's cv2 visible inside the venv.
python3 -m venv --system-site-packages "$PYNQ_VENV"
cat > "$PYNQ_VENV/constraints.txt" <<EOF
# pynq $PYNQ_VERSION and pynqutils both require numpy < 2
numpy<2
# pycparser 3.0 removed pycparser.plyparser, which pynq.lib imports
pycparser<3
pynq==$PYNQ_VERSION
EOF
export PIP_CONSTRAINT=$PYNQ_VENV/constraints.txt
# shellcheck disable=SC1091
source "$PYNQ_VENV/bin/activate"
pip install --quiet -U pip setuptools wheel pybind11

echo "==> Building pyxrt from XRT $XRT_TAG"
site=$(python3 -c 'import sysconfig; print(sysconfig.get_paths()["platlib"])')
suffix=$(python3 -c 'import sysconfig; print(sysconfig.get_config_var("EXT_SUFFIX"))')
build=$(mktemp -d)
curl -fsSL -o "$build/pyxrt.cpp" \
    "https://raw.githubusercontent.com/Xilinx/XRT/$XRT_TAG/src/python/pybind11/src/pyxrt.cpp"
g++ -O2 -shared -fPIC -std=c++17 $(python3 -m pybind11 --includes) \
    -I/usr/include/xrt "$build/pyxrt.cpp" -o "$site/pyxrt$suffix" \
    -lxrt_coreutil -luuid -lpthread
rm -rf "$build"
python3 -c 'import pyxrt' && echo "OK: pyxrt imports"

echo "==> Installing PYNQ $PYNQ_VERSION and JupyterLab"
pip install "pynq==$PYNQ_VERSION" jupyterlab ipywidgets

echo "==> Installing the MicroBlaze toolchain"
# The base overlay's Pmod and Grove drivers compile MicroBlaze code at run time.
# xclbinutil, the other thing in this tarball, now comes with noble's xrt package.
tarball=$(mktemp)
wget -q -O "$tarball" "https://www.xilinx.com/bin/public/openDownload?filename=pynq-v3.0-binaries.tar.gz"
[ "$(file --mime-type -b "$tarball")" = application/gzip ] || die "PYNQ binaries download is not a tarball"
tar -xzf "$tarball" -C "$PYNQ_VENV/bin" --strip-components=2 pynq-v3.0-binaries/gcc-mb/microblazeel-xilinx-elf
rm -f "$tarball"
sed -i "s|/opt/microblaze|$PYNQ_VENV/bin|g" "$site/pynq/lib/pynqmicroblaze/rpc.py"

echo "==> Installing the KV260 base overlay and the Composable Pipeline"
pip install --no-build-isolation "$SRC"
composable=$(mktemp -d)
git clone --quiet --depth 1 -b "$COMPOSABLE_REF" https://github.com/Xilinx/PYNQ_Composable_Pipeline.git "$composable"
pip install --no-build-isolation "$composable"
rm -rf "$composable"
( cd / && python3 -c 'import pynq, pynq.lib, kv260, pynq_composable' ) && echo "OK: pynq, pynq.lib, kv260 and pynq_composable import"

echo "==> Writing /etc/profile.d/pynq_venv.sh"
cat > /etc/profile.d/pynq_venv.sh <<EOF
source $PYNQ_VENV/bin/activate
export BOARD=$BOARD
export XILINX_XRT=/usr
export PYNQ_JUPYTER_NOTEBOOKS=$NB_DIR
export PIP_CONSTRAINT=$PYNQ_VENV/constraints.txt
export PATH=\$PATH:$PYNQ_VENV/bin/microblazeel-xilinx-elf/bin
EOF

echo "==> Building the PYNQ device tree overlay"
# Kria-PYNQ's fragments (AFI ports, zocl, a UIO interrupt), plus a /chosen/pynq_board
# property. PYNQ 3.1 only treats the system as a board, and only imports pyxrt, when
# /proc/device-tree/chosen/pynq_board exists. PYNQ 3.0.1 didn't check, so Kria-PYNQ
# never added it.
mkdir -p "$PYNQ_VENV/pynq-dts"
{
    sed '$d' "$SRC/dts/pynq.dts"        # drop the closing "};"
    cat <<EOF
	/* PYNQ 3.1 board detection */
	fragment@4 {
		target-path = "/chosen";
		__overlay__ {
			pynq_board = "$BOARD";
		};
	};
};
EOF
} > "$PYNQ_VENV/pynq-dts/pynq.dts"
dtc -q -I dts -O dtb -o "$PYNQ_VENV/pynq-dts/pynq.dtbo" "$PYNQ_VENV/pynq-dts/pynq.dts"

echo "==> Configuring JupyterLab on port 9090"
mkdir -p "$NB_DIR"
cp -r "$site/kv260/notebooks/." "$NB_DIR/kv260/" 2>/dev/null || true
chown -R "$NB_USER:" "$NB_DIR"
hash=$(python3 -c 'from jupyter_server.auth import passwd; print(passwd("xilinx"))')
mkdir -p /root/.jupyter
cat > /root/.jupyter/jupyter_server_config.py <<EOF
c.ServerApp.ip = "0.0.0.0"
c.ServerApp.port = 9090
c.ServerApp.root_dir = "$NB_DIR"
c.ServerApp.open_browser = False
c.ServerApp.allow_root = True
c.PasswordIdentityProvider.hashed_password = "$hash"
EOF

echo "==> Installing systemd units"
cat > /etc/systemd/system/pynq-dtbo.service <<EOF
[Unit]
Description=Insert the PYNQ device tree overlay
After=sys-kernel-config.mount

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'd=/sys/kernel/config/device-tree/overlays/pynq; [ -d \$d ] || { mkdir \$d && cat $PYNQ_VENV/pynq-dts/pynq.dtbo > \$d/dtbo; }'

[Install]
WantedBy=multi-user.target
EOF
cat > /etc/systemd/system/jupyter.service <<EOF
[Unit]
Description=JupyterLab for PYNQ
After=network-online.target pynq-dtbo.service
Wants=pynq-dtbo.service

[Service]
Type=simple
WorkingDirectory=$NB_DIR
ExecStart=/bin/bash -c 'source /etc/profile.d/pynq_venv.sh && exec jupyter lab'
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
if [ $HAVE_SYSTEMD = 1 ]; then
    systemctl daemon-reload
    systemctl enable pynq-dtbo.service jupyter.service
    [ $HAVE_FPGA = 1 ] && systemctl start pynq-dtbo.service jupyter.service
else
    echo "   no systemd: units written, not enabled"
fi

echo
echo "Done. PYNQ $PYNQ_VERSION is in $PYNQ_VENV, notebooks in $NB_DIR."
if [ $HAVE_FPGA = 1 ]; then
    echo "Reboot, then run: sudo ./check-pynq.sh"
    echo "JupyterLab: http://$(hostname):9090/lab   password: xilinx"
else
    echo "No FPGA manager found, so nothing was loaded. This was not a board."
fi
