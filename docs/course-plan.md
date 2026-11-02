# Course plan

How this course is put together, and why. Written in October 2026, before the first
lesson, from bring-up on the DE25-Nano and offline tests for the KV260.

## Can two different SoC boards share one course?

Course 1 could promise "every core lesson runs on either board" because the MAX1000 and
the Tang Nano 20K differ only in pins and toolchain, and `board_top.sv` hides both. The
KV260 and the DE25-Nano differ far more: different vendors, different processor
subsystems, different ways of assembling a platform and loading a bitstream.

They can still share lessons, but only one level up. A per-board shell plays the part
`board_top.sv` played in course 1. It hides the processor system: the block design or
Platform Designer system, the bridges, the clocks, the path into memory and the boot.
Above the shell the two boards look the same to a student. Below it, everything is
written twice, once per board, by the course and not by the student.

| Layer | KV260 | DE25-Nano | Same for the student? |
|---|---|---|---|
| Lesson RTL | SystemVerilog subset, Vivado | same subset, Quartus Pro | yes |
| Generator | Amaranth to Verilog | same | yes |
| Simulation | cocotb + cocotbext-axi, Icarus, Verilator | same | yes |
| Processor to fabric | AXI4 (HPM, HP ports) | AXI4 (H2F, LW-H2F, F2H bridges) | yes, at the shell's ports |
| Platform assembly | Vivado block design, from Tcl | Platform Designer, from Tcl | no, this is the shell |
| Clock and reset | `pl_clk0` from the PS | an IOPLL from the board's 50 MHz | yes, the shell hands over `clk` and `rst` |
| DMA | the student's AXI4 master into HP0 | the student's AXI4 master into F2H | yes, if students write the DMA |
| Linux driver | UIO + u-dma-buf | UIO + u-dma-buf | yes |
| Cache coherency | HP ports are not coherent | F2H can go through the CCU | hidden in the library's sync call |
| Loading a bitstream | FPGA manager overlay from Linux | Linux overlay path has bug reports; U-Boot `fpga load` works | no, the largest open risk |
| Board I/O | one Pmod, 8 pins | 72 pins | yes, if core lessons use 8 pins |
| Camera | AMD's free MIPI CSI-2 IP | Altera's CSI-2 IP, now with a no-cost licence | no, core lessons use a USB camera |
| Real-time cores | 2× R5F | none | no, core lessons use your course-1 RISC-V in the fabric |
| ML compiler | FINN, DPU | none | no, core lessons use your own engine |
| Board OS | Canonical 24.04 + Jazzy | our 24.04 + Jazzy image | yes |

The count that comes out of this is about 26 core lessons on both boards and 11 optional
ones on one, close to course 1's ratio. Eight of the optional ones are KV260-only,
because AMD has more free IP for it.

## The shell

Every lesson's design sees the same ports on both boards:

| Port | What it is |
|---|---|
| `clk`, `rst` | the fabric clock, 100 MHz by default, and an active-high synchronous reset, as in course 1 |
| `s_axil_*` | an AXI4-Lite slave, the lesson's registers, at a base address given in `board.json` |
| `m_axi_*` | an AXI4 master into the processor's DDR, for DMA |
| `irq` | one interrupt line to Linux |
| `gpio[7:0]` | 8 pins, the link to the course-1 actuator board |

A lesson declares the ports it uses, and the shell ties off the rest, the same rule as
course 1's wrapper. `board.svh` keeps the facts RTL needs. `board.json` keeps the ones
the board library needs: base address, interrupt, UIO name.

## Three loops

| Loop | Planned targets | Time |
|---|---|---|
| A, host | `sim`, `ex`, `wave`, `lint`, `gen`, `probe` | seconds |
| B, target | `deploy`, `run`, `test-target`, `load` | seconds on the KV260; unknown on the DE25 until runtime reload is tested |
| C, rebuild | `synth`, `report` | 10 to 40 minutes |

Loop C is slow enough that the course avoids it on purpose. A lesson's bitstream loads
once, and most exercises iterate on software and tests against it.

## Toolchain

| Where | What | Board |
|---|---|---|
| image `sim` | course 1's `oss` image plus Amaranth and cocotbext-axi | both |
| image `vivado` | Vivado 2026.1, Zynq UltraScale+ only | KV260 |
| image `quartus-pro` | Quartus Prime Pro 25.1.1 + Agilex 5 | DE25-Nano |
| image `ros` | the multi-arch ROS 2 Jazzy image from hello_ros2 | both |
| host | GTKWave, ssh, qemu binfmt for arm64, Quartus Pro's `quartus_pgm` for JTAG | |
| board | Ubuntu 24.04 arm64, Jazzy ros-base, the board library, u-dma-buf | both |

Quartus Pro 25.1.1 is pinned because Terasic's `golden_top` and boot sources are built
with it. Both vendors' licences now expire yearly: Vivado's Basic tier is an annual
subscription, and the Agilex 5 E-series licence is valid for one year. The Agilex licence
is node-locked to the host's network card, so a Quartus container needs that MAC address
and the licence file passed in.

## Taken from course 1

The make driver (`make board B=`, `L=`, `E=`, `list`), `mk/common.mk` with its PASS/FAIL
gate and exercise retargeting, the per-toolchain `mk/` split, `scripts/dock`, pinned and
checked installers, `check-env.sh`, `check-lessons.sh`, the one-report-for-every-board
`report.py`, the `lib/` rules, the README format with hints and a quiz, and lettered
optional lessons. What doesn't carry over is openFPGALoader, which can't program
Agilex 5 and isn't needed on the KV260, along with `flash` and `flash-temp`.

## Decisions

Made:

- High-level design uses a generator language on both boards, not vendor C++ HLS.
  Altera discontinued its HLS Compiler and oneAPI dropped FPGA support in 2025.1, so
  Vitis HLS can only be a KV260 extra.
- The board library is ours, the same API on both boards: UIO for registers and
  interrupts, u-dma-buf for buffers. PYNQ is a KV260 extra.
- Students bring their own course-1 `lib/`, with course 1's reference answers as a
  fallback, and their course-1 board is the actuator.

Open:

- Amaranth or SpinalHDL. Amaranth is the current choice, because it's Python like
  cocotb, the board library and rclpy.
- Whether "core lessons on both boards" holds, which depends on the first risk below.

## Risks

| Risk | Status |
|---|---|
| Reloading the DE25 fabric from Linux at runtime | open. If it fails, Loop B on the DE25 means a reboot through U-Boot, about a minute |
| The factory QSPI bootloader accepting our U-Boot | mostly retired. Factory and ours are built from the same commits |
| Licences inside containers | partly known. The Agilex licence is tied to the host MAC address |
| u-dma-buf on both kernels | untested. Can be tested offline against both kernels |
| CMA size on the DE25 | known. 32 MB in the factory kernel, too small for video |
| KV260 hardware | untested. PYNQ, zocl and overlays have only run in emulation |
