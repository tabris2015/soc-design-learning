# SoC design learning

The second course after [digital-design-learning](https://github.com/tabris2015/hello_max10).
Course 1 ends with a RISC-V core you built closing a motor loop on a small FPGA. This one
moves to SoC FPGAs, where an ARM processor running Linux sits next to the fabric, and asks
the question robotics keeps asking: which part of the job belongs in hardware, and what
does moving data between the two halves cost?

The goal is accelerated robotics. You build fabric accelerators in SystemVerilog and a
Python hardware generator, drive them from Linux and ROS 2 on the same chip, and close the
loop through your course-1 board as the actuator controller. Running packaged AI models
on a vendor inference engine is not the point, and it appears only as optional lessons.

Status: board bring-up. The DE25-Nano boots, programs over JTAG and runs a first design.
The KV260 side is tested offline only. No lessons are written yet, and the build system
arrives with lesson 01. [docs/course-plan.md](docs/course-plan.md) is the design.

## Boards

You need one of these, not both.

| | AMD Kria KV260 | Terasic DE25-Nano |
|---|---|---|
| Chip | Zynq UltraScale+ `XCK26`, 256K logic cells | Agilex 5 E-series `A5EB013BB23BE4SCS`, 138K LE |
| Processor | 4× Cortex-A53, 2× Cortex-R5F | 2× Cortex-A76, 2× Cortex-A55 |
| Memory | 4 GB DDR4, shared | 1 GB LPDDR4 for the HPS, 1 GB LPDDR4 for the fabric, 128 MB SDRAM |
| Toolchain | Vivado 2026.1 | Quartus Prime Pro 25.1.1 |
| Board OS | Canonical Ubuntu 24.04 for Kria | our Ubuntu 24.04 image, built in this repo |
| Free I/O | one Pmod, 8 pins | two 2×20 headers, 72 pins |
| Extras | MIPI camera, DisplayPort, video codec, R5F real-time cores | HDMI out, 2-lane MIPI, ADC, accelerometer |

Both run Ubuntu 24.04 and ROS 2 Jazzy, the same as the host. Core lessons run on either
board, through a per-board shell that hands your design the same clock, reset, register
bus and memory port on both. Lessons that need one board's hardware carry a letter
(`15a`), as in course 1.

## Course map

| Part | Lessons | Core, both boards | Optional, one board |
|---|---|---|---|
| 1. Platform | 01-04 | first boot, the shell, the board library and tests on the target, loading logic at runtime | PYNQ (KV260) |
| 2. Buses | 05-09 | AXI4-Lite, interrupts, AXI4-Stream, your own DMA, measured bandwidth and coherency | |
| 3. Generators | 10-14 | Amaranth from your course-1 modules, pipelines and fixed point, memories, dataflow, an accelerator end to end | Vitis HLS (KV260) |
| 4. Vision | 15-17 | frames from a USB camera, image kernels in the fabric, pixels out through Linux | MIPI on each board, Vitis Vision and the video codec (KV260), HDMI from the fabric (DE25) |
| 5. ML | 18-20 | quantisation, your own fixed-point network engine, choosing fabric or CPU | FINN, DPU (KV260) |
| 6. Real time | 21-22 | your course-1 RISC-V as the fabric's real-time core, jitter measured | R5F and OpenAMP (KV260), PREEMPT_RT (DE25) |
| 7. ROS 2 | 23-25 | ROS 2 on the board, an accelerated node, `ros2_control` to your course-1 board | |
| 8. Capstone | 26 | camera to fabric to ROS 2 to the actuator board | |

Course 1 is the prerequisite. Its `lib/` (UART, PWM, encoder, PID, your RISC-V core) is
the starting material here, and your MAX1000 or Tang Nano 20K becomes the actuator half
of the capstone.

## What works today

| | DE25-Nano | KV260 |
|---|---|---|
| Host toolchain | Quartus Prime Pro 25.1.1 with Agilex 5, licensed, compiles | not installed yet |
| Programming | JTAG over the on-board USB-Blaster III | |
| Console | FT4232H serial port, scripted login | |
| First design | LED0 blinks, [boards/de25nano/first-light](boards/de25nano/first-light) | |
| Board OS | Ubuntu 24.04 + Jazzy image builds, not yet booted | PYNQ 3.1.2 install script passes in an emulated arm64 container |

For the DE25-Nano, from a bare Ubuntu 24.04 host:

```bash
./scripts/setup-udev.sh               # USB-Blaster III and its serial ports
./scripts/install-quartus-pro.sh      # after downloading the four files it lists
# Licence: see docs/gotchas.md, the in-app "Get no-cost licenses" fails on 25.1.1
cd boards/de25nano/first-light
quartus_sh --flow compile blink
quartus_pgm -c "DE25-Nano [1-3]" -m jtag -o "p;output_files/blink.sof@1"
```

## Layout

```
boards/de25nano/   board.md, os/ (boot, rootfs and SD image builds), first-light/
boards/kv260/      board.md, os/ (PYNQ on Ubuntu 24.04)
scripts/           host setup: udev, Quartus Pro install, serial console helpers
docs/              course plan, gotchas, and the earlier KV260-only syllabus draft
build/             generated, git-ignored
```

The lesson directories, `mk/`, `docker/` and `lib/` arrive with the first lesson, in
course 1's shape.

## Reference

- [docs/course-plan.md](docs/course-plan.md) is the design: why both boards can share
  lessons, the shell, the three loops, the toolchain, and the open risks.
- [docs/gotchas.md](docs/gotchas.md) collects what surprised us during bring-up.
- [boards/de25nano/board.md](boards/de25nano/board.md) and
  [boards/kv260/board.md](boards/kv260/board.md) describe each board.
- [docs/kv260-draft-syllabus.md](docs/kv260-draft-syllabus.md) is the earlier KV260-only
  syllabus, kept for its research notes.
