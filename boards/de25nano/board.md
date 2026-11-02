# Terasic DE25-Nano

Rev B board, checked on hardware in October 2026. The PCB revision is printed on a seal on
the bottom of the board: `A0` or `B0`. The only documented difference is the fabric-side
LPDDR4, which runs at 2133 MT/s on rev A and 2666 MT/s on rev B.

## Specs

| Block | |
|---|---|
| FPGA | Agilex 5 E-series `A5EB013BB23BE4SCS`, 138K LE (46,800 ALMs), 351 user pins |
| HPS | 2× Cortex-A76, 2× Cortex-A55 |
| Memory | 1 GB LPDDR4 on the HPS (shareable with the fabric), 1 GB LPDDR4 on the fabric, 128 MB SDRAM (16-bit) |
| Storage | 128 Mbit QSPI flash (boot), microSD |
| FPGA I/O | two 2×20 GPIO headers (3.3 V), HDMI TX up to 1080p, 2-lane MIPI connector, 8-channel ADC on a 2×5 header, 8 LEDs, 2 buttons, 4 slide switches |
| HPS I/O | Gigabit Ethernet, USB 2.0 OTG on Type-C, LIS2DW12 accelerometer, 1 LED, 1 button, cold reset (KEY3) |
| Clocks | three 50 MHz to the fabric, 25 MHz to the HPS |
| Debug | one Type-C port: USB-Blaster III plus two serial ports (FT4232H) |
| Power | 5 V DC jack. Active heatsink with its own fan controller |

## Connections

| Connector | Use |
|---|---|
| 5 V DC jack | power, with the supply from the box |
| USB-C, Blaster | JTAG and the console. This is the one for your PC |
| USB-C, OTG | the HPS's USB port. A PC here sees nothing |
| RJ45 | Ethernet, for SSH once Linux is up |
| SW5 | configuration mode. Factory setting SW5.1 OFF, SW5.2 ON, SW5.3 ON boots from QSPI. JTAG programming works without changing it |

## Seen from the host

| | |
|---|---|
| USB | `09fb:6026` "DE25-Nano", TERASIC |
| JTAG cable | `DE25-Nano [<bus>-<port>]` in `jtagconfig` |
| JTAG device | IDCODE `4362C0DD`, `A5E(A013BB23B\|B013BB23BCS)` |
| Console | `/dev/serial/by-id/usb-TERASIC_DE25-Nano_<serial>-if02-port0`, 115200 8N1 |
| Second serial port | `...-if03-port0`, silent at boot |

[scripts/console.py](../../scripts/console.py) logs in and runs commands over the console.
[scripts/wait-login.py](../../scripts/wait-login.py) waits for a boot to reach the login
prompt without typing anything.

## Factory state

The QSPI holds Terasic's factory design and the first-stage bootloader (U-Boot SPL
2025.01-gd0f8813fd6bf). It loads U-Boot, the kernel and a root filesystem from the
microSD card that ships with the board: Ubuntu 22.04.3 with Linux 6.12.11, user `terasic`,
password `123`.

Measured at idle on that image:

| | |
|---|---|
| Die temperature | 27 to 31 °C |
| VCC, VCCL | 0.825 V |
| VCCH | 0.823 V, on a channel labelled 0.9 V. Check against the schematic |
| VCCIO_SDM, VCCPT | 1.81 V |
| VCCCRCORE | 1.21 V |
| CPU clocks | all four cores at 800 MHz, DSU 533 MHz, NoC 400 MHz, no cpufreq |
| RAM | 934 MB usable, 32 MB CMA |
| HPS I²C bus 0 | the accelerometer at 0x19, nothing else |

The fan runs at full speed and FAN_ALERT (D16) stays lit, whatever design is loaded. See
[docs/gotchas.md](../../docs/gotchas.md).

## Our image

[os/](os/) builds Ubuntu 24.04 with ROS 2 Jazzy for this board, with no root or loop
devices, entirely in Docker:

```bash
boards/de25nano/os/build-boot.sh      # ATF, U-Boot and Linux from Terasic's branches
boards/de25nano/os/build-rootfs.sh    # Ubuntu 24.04 arm64 + ros-jazzy-ros-base
boards/de25nano/os/build-sdimage.sh   # build/de25nano/os/sd/de25-nano-noble-jazzy.img
```

U-Boot and the kernel are built from the same commits as the factory boot, so the factory
SPL in QSPI should load them. The image builds and passes `fsck`, and ROS 2 runs in it
under emulation. It hasn't booted on the board yet. Write it to a second card and keep the
factory one.

## First light

[first-light/](first-light/) blinks LED0 at about 0.75 Hz from `CLOCK0_50`. It's the
smallest check that synthesis, fitting, timing, the bitstream and JTAG all work.

```bash
cd boards/de25nano/first-light
quartus_sh --flow compile blink
quartus_pgm -c "DE25-Nano [1-3]" -m jtag -o "p;output_files/blink.sof@1"
```

It takes 14 ALMs and meets timing at 50 MHz. Loading it stops the factory Linux, and a power
cycle brings it back.

## References

- DE25-Nano user manual and resource packages:
  <https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&CategoryNo=115&No=1384&PartNo=4>
- Board revision document:
  <https://www.terasic.com.tw/wiki/DE25-Nano_Board_Revision_Document>
- Terasic's Linux build guide, which our OS scripts follow:
  <https://github.com/johnnyfan1979/public_doc/blob/main/documentation/DE25_Nano/DE25%20Nano%20Build%20Linux%20image%20from%20scratch.md>
