# Gotchas

Tool and board behaviour that cost time during bring-up. Each entry was hit on real
hardware or in a build, not taken from documentation.

## DE25-Nano

### The board has two USB-C ports, and only one reaches your PC

One Type-C port is the USB-Blaster III, which also carries the serial console. The other
is the HPS's USB 2.0 OTG port, which acts as a host, so a PC plugged into it sees nothing.
Power comes from the 5 V DC jack, not from either USB port. If `lsusb` shows nothing, the
cable is in the OTG port. The small JTAG status LED next to the Blaster port turns blue
when it's plugged into a PC.

### The USB-Blaster III is `09fb:6026`, not `6022`

The ID usually quoted for the USB-Blaster III is `6022`. This board enumerates as
`09fb:6026`, "DE25-Nano" by TERASIC, so a udev rule written for `6022` leaves JTAG
root-only. [scripts/setup-udev.sh](../scripts/setup-udev.sh) matches Altera's vendor ID
instead.

### The console is the first of the two serial ports

The Blaster is an FT4232H. Its interfaces 2 and 3 become `ttyUSB0` and `ttyUSB1`, and
the kernel binds them with no extra driver. The HPS console, `ttyS0` at 115200, is
interface 2: `/dev/serial/by-id/usb-TERASIC_DE25-Nano_<serial>-if02-port0`. Interface 3
is silent at boot.

### ModemManager probes the serial ports

Ubuntu's ModemManager sends AT commands to new serial ports, which lands as garbage on
the board's console. The udev rule sets `ID_MM_DEVICE_IGNORE` for Altera's vendor ID.

### Pressing a key during boot stops it

U-Boot counts down five seconds before booting, and any byte on the console stops it.
A script that pokes the console to see whether the board is up will halt the boot it is
waiting for. [scripts/wait-login.py](../scripts/wait-login.py) only reads.

### The Blaster survives a power cycle

The USB-Blaster III is powered from USB, so pulling the 5 V supply resets the FPGA and
the HPS but leaves the Blaster and its serial ports enumerated. A serial capture keeps
running through a reboot.

### JTAG programming works without touching SW5

The manual says to set SW5 to JTAG mode before programming over JTAG. It isn't
necessary. With SW5 at its factory AS setting, `quartus_pgm` configures the FPGA in about
two seconds. A full-chip `.sof` replaces the factory design and stops the HPS, and a power
cycle reloads both from QSPI.

### The fan always runs flat out, and FAN_ALERT stays lit

The die sits near 30 °C at idle and the fan still runs at full speed, with the orange
FAN_ALERT LED (D16) on. The controller isn't visible to software: no FPGA pins in the
manual, and nothing but the accelerometer (0x19) on the HPS I²C bus. The schematic in
Terasic's resource package should name the part.

### The factory boot runs every CPU core at 800 MHz

The clock tree shows all four cores, the A76s included, at 800 MHz, the DSU at 533 MHz
and the NoC at 400 MHz, with no cpufreq driver. The A76s can run much faster, so
benchmarks on the factory setup understate the board.

### CMA is 32 MB

The factory kernel reserves 32 MB of contiguous memory, too little for camera frames.
Raise it with `cma=` on the kernel command line.

### Pins are 1.1 V

`CLOCK0_50` (`PIN_DJ35`) and the user LEDs sit in 1.1 V banks. Quartus wants
`IO_STANDARD "1.1-V"` on each, and without a location and an I/O standard on every pin
the assembler writes no bitstream at all, with only a critical warning to say so.

## Quartus Prime Pro

### "Get no-cost licenses" fails on 25.1.1

The in-app licence button says "Unable to fetch product list" and blames the network.
The network is fine: Quartus calls `https://apis.intel.com/m2r/api/v1/`, which is
reachable, and TLS verifies with Quartus's own certificate bundle. The token built into
this July 2025 release is rejected. Request the Agilex 5 E-series licence from the
Self-Service Licensing Center at <https://licensing.altera.com/sslc/s/> instead,
node-locked to the NIC ID that `lmutil lmhostid` prints for your wired Ethernet port.

### The licence file arrives with a BOM and Windows line endings

Strip both before installing it (`sed '1s/^\xEF\xBB\xBF//' | tr -d '\r'`). Quartus
happened to accept the original here, but FlexLM's parser is picky and the cleaned copy
costs nothing.

### The GUI stores the licence path where the command line reads it

Tools > License Setup writes `LICENSE_FILE` into `~/.altera.quartus/quartus2.ini`, and
`quartus_syn`, `quartus_fit` and the rest read it from there. That's why command-line
builds work without `LM_LICENSE_FILE`, and why a build in a container, with a different
home directory, will not.

### `quartus_sh --tcl_eval` can't load the device package

As in course 1's Quartus Lite. A device query such as `get_part_list` needs a script file
run with `quartus_sh -t`.

### An unattended install can trip over components you didn't download

The installer selects every component it knows about, device families you didn't fetch
included. [scripts/install-quartus-pro.sh](../scripts/install-quartus-pro.sh) reads the
component list from `--help` and disables everything except the base tool and Agilex 5.

## KV260 and Ubuntu 24.04

### Kria-PYNQ's installer only runs on Ubuntu 22.04

Patching its version check isn't enough. The PYNQ 3.0.1 it installs calls XRT's legacy
`xcl*` functions, which noble's XRT 2.18 no longer exports. PYNQ 3.1 uses `pyxrt`, which
nobody packages for noble, so
[boards/kv260/os/install-pynq-noble.sh](../boards/kv260/os/install-pynq-noble.sh) builds it.

### PYNQ 3.1 won't believe it's on a board without `/chosen/pynq_board`

It reads the board name from `/proc/device-tree/chosen/pynq_board`. The install script
adds that node in its device tree overlay.

### `pycparser` 3.0 breaks `pynq.lib`

Pin `pycparser<3`, along with `numpy<2`.

### zocl is not in Canonical's kernel

It comes from `xrt-dkms`, which builds it on the board against the running kernel's
headers.

## Docker and the build

### The local `ubuntu:24.04` tag may be arm64

On a host that has pulled arm64 images, `ubuntu:24.04` can resolve to the arm64 one, and
an amd64 cross-build then runs under emulation, many times slower. The OS build scripts
pin `--platform linux/amd64` and pull `ubuntu:noble` explicitly.

### `/tmp` may be a tmpfs

On many hosts `/tmp` lives in RAM, and a kernel tree plus a rootfs can fill it. The OS
builds work under `build/` on disk instead.
