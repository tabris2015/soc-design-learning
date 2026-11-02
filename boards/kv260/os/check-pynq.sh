#!/usr/bin/env bash
# Check that PYNQ works on the board after ./install-pynq-noble.sh.
#
# Everything the container test could not reach: the zocl driver, the device tree
# overlay, bitstream loading, allocate() and MMIO. Step 7 loads the KV260 base
# overlay, which replaces whatever is in the PL.
#
# On the board:  sudo ./check-pynq.sh

[ "$EUID" -eq 0 ] || { echo "run as root: sudo $0"; exit 1; }

echo "=== 1. OS and kernel ==="
. /etc/os-release; echo "$PRETTY_NAME, kernel $(uname -r), $(uname -m)"

echo
echo "=== 2. XRT ==="
dpkg-query -W -f='xrt ${Version}\n' xrt 2>/dev/null || echo "NOT INSTALLED"

echo
echo "=== 3. zocl driver and its DRM node ==="
lsmod | grep -w zocl || echo "zocl not loaded (it binds when the overlay in step 4 adds its node)"
ls -l /dev/dri/renderD* 2>/dev/null || echo "no /dev/dri/renderD* node"

echo
echo "=== 4. Device tree overlay ==="
echo "Overlays: $(ls /sys/kernel/config/device-tree/overlays/ 2>/dev/null | tr '\n' ' ')"
if [ -f /proc/device-tree/chosen/pynq_board ]; then
    echo "OK: pynq_board = $(tr -d '\0' < /proc/device-tree/chosen/pynq_board)"
else
    echo "!! /proc/device-tree/chosen/pynq_board missing. PYNQ 3.1 will think it is"
    echo "   not on a board and never import pyxrt. Check: systemctl status pynq-dtbo"
fi

echo
echo "=== 5. Kria app manager ==="
echo "If an accelerated app is loaded here, run 'xmutil unloadapp' before step 7."
command -v xmutil >/dev/null && xmutil listapps 2>&1 | tail -n +1 || echo "  (xmutil not installed)"

echo
echo "=== 6-9. PYNQ ==="
# shellcheck disable=SC1091
source /etc/profile.d/pynq_venv.sh
cd /tmp && python3 - <<'EOF'
import time

def step(n, name, fn):
    try:
        print(f"OK   {n}. {name}: {fn()}")
        return True
    except Exception as e:
        print(f"FAIL {n}. {name}: {type(e).__name__}: {e}")
        return False

import pynq, pynq.ps
step(6, "pynq and pyxrt",
     lambda: f"pynq {pynq.__version__}, ON_TARGET={pynq.ps.ON_TARGET}, "
             f"pyxrt={__import__('pyxrt').__name__}, devices={pynq.Device.devices}")

ol = None
def load():
    global ol
    from kv260 import BaseOverlay
    t = time.perf_counter()
    ol = BaseOverlay("base.bit")
    return f"{time.perf_counter() - t:.2f} s, {len(ol.ip_dict)} IPs"
if not step(7, "load the base overlay", load):
    raise SystemExit(1)

def alloc():
    import numpy as np
    buf = pynq.allocate((4096,), dtype=np.uint32)
    buf[:] = np.arange(4096, dtype=np.uint32)
    buf.flush()
    buf.invalidate()
    ok = bool((buf == np.arange(4096, dtype=np.uint32)).all())
    addr = buf.physical_address
    buf.freebuffer()
    return f"16 KiB at 0x{addr:x}, readback {'matches' if ok else 'DIFFERS'}"
step(8, "allocate() a DMA buffer", alloc)

def mmio():
    name, ip = next((k, v) for k, v in ol.ip_dict.items() if v.get("phys_addr"))
    val = pynq.MMIO(ip["phys_addr"], 0x100).read(0)
    return f"{name} at 0x{ip['phys_addr']:x}, reg 0 = 0x{val:08x}"
step(9, "MMIO read", mmio)
EOF

echo
echo "=== 10. JupyterLab ==="
systemctl is-active jupyter.service
curl -s -o /dev/null -w "http://localhost:9090/lab -> HTTP %{http_code}\n" http://localhost:9090/lab \
    || echo "not answering on 9090"
