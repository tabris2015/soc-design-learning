# Course guide

> Draft from September 2026, written for a KV260-only course before the two-board plan in
> [course-plan.md](course-plan.md). Kept for its research notes. Lesson numbers and some
> conventions here (Verilog-2001, the lesson layout) are out of date.

Heterogeneous system design on a Zynq UltraScale+ MPSoC, from the first custom bitstream to
an accelerated perception-to-action pipeline, all on a Kria KV260.

This document is the spine of the course. It says what each lesson covers, what you build
in it, what hardware it needs, and where to read more. The lesson READMEs do the teaching.
This is the map.

**Status: proposed.** No lessons are written yet. This is the design document, drafted
against the sibling course's structure and the university material listed at the end. The
only code so far is the PYNQ install script and its board check under `scripts/`.

---

## Goal

Practical competence in hardware/software co-design, aimed at robotics. By the end you
should be able to look at a perception or control problem and decide, with measurements
rather than taste, which parts belong on the application processors, which in fabric, which
on a real-time core, and how the data moves between them without the transfer costing more
than the computation saves.

The target is accelerated robotics: a robot whose perception and control run partly in
fabric, measured end to end. Using the KV260 as a neural-network inference box is not the
goal. A Jetson does that far better, and the course only touches inference where it teaches
something about hardware.

That is a different skill from the one [hello_max10](https://github.com/tabris2015/hello_max10) builds. The board
is not a bigger MAX 10, and it helps to be explicit about how.

| | hello_max10 | hello_kria |
|---|---|---|
| Device | MAX 10, 8,064 LEs, no processor | Zynq UltraScale+, 117,120 LUTs **and a quad-core Linux SoC** |
| Core question | *How do I describe this circuit correctly?* | *Where in this system does this work belong?* |
| Direction | Bottom-up, from a gate | Top-down, from a system |
| Unit of work | A module | An accelerator behind an interface |
| Language | Verilog-2001 | Verilog, C++ (HLS), Python, some C |
| Target | A bitstream | A Linux userspace application with fabric under it |
| The hard part | Getting the RTL right | Getting the data there, and proving it was worth it |
| Robotics enters via | Motors, encoders, a PID loop | Cameras, inference, ROS 2, a latency budget |

The MAX 10 course cut video because the board had none. On this board video is the whole
point, and it comes back as four lessons.

Cost is the other thing that changes. On the MAX 10 a design either fitted or it didn't.
Here almost everything fits, so the question becomes whether the accelerator you built beat
the four A53 cores you already had. The answer is "no" more often than you'd like, and data
movement is usually why, not compute. Lessons 09 and 14 make you measure it instead of
assuming it.

## Prerequisites

**[hello_max10](https://github.com/tabris2015/hello_max10), or equivalent RTL competence.** This course does not
re-teach flip-flops, blocking versus non-blocking assignment, FSM coding style, timing
closure or fixed-point arithmetic. It assumes you can write and verify a clocked Verilog
module and read a utilisation report, and it starts at the system level.

Beyond that you need C++ you would not be embarrassed by, Python, and enough Linux to be
comfortable with a device tree, `systemd`, and an SSH session to a machine you can brick.

These carry forward from hello_max10 and are not taught again:

| From hello_max10 | Used here as |
|---|---|
| Ready/valid handshake (09, 11) | AXI4-Stream, the same protocol with a standard behind it |
| Fixed-point Q-format (12) | `ap_fixed<>` in HLS, and the DPU's INT8 |
| Pipelining and f<sub>max</sub> (13) | HLS `PIPELINE`, initiation interval, `DATAFLOW` |
| FIR/IIR filters (19) | The first HLS accelerator, and the vision line buffers |
| Memory-mapped peripherals (23) | AXI4-Lite register interfaces |
| Closed-loop PID (24) | The R5F real-time lesson, and the capstone |

---

## How the course works

### The three loops

The sibling course had two loops. This one has three, and the third is expensive enough
that the whole course is arranged around avoiding it.

```
  Loop A: host                     Loop B: target                   Loop C: rebuild PL
  ────────────                     ──────────────                   ──────────────────
  HLS C simulation                 swap a PYNQ overlay              Vivado synth + impl
  pytest / cocotb                  rerun the notebook               package + implement

  ~1 second                        ~2 seconds                       ~20-40 minutes
```

Loop A finds algorithm and interface bugs. Loop B finds everything about the *system*:
address maps, DMA, cache coherency, driver behaviour, real throughput. It is nearly as fast
as simulation because the bitstream does not change. Only Loop C can tell you about
resources, timing closure and I/O, so enter it on purpose, not by accident.

Treat the 40-minute build as a design constraint. It is why this course leans on PYNQ far
more than a vendor tutorial would. An overlay you can reload in two seconds from a Jupyter
cell moves most of the course into Loop B, and leaves Loop C for the handful of lessons
that are about the fabric itself.

### Anatomy of a lesson

```
lessons/13-dataflow/
  README.md      the study material: concept, worked example, why it matters
  hls/           the HLS sources the README walks through
  rtl/           any handwritten Verilog
  sim/           C testbenches and cocotb, all passing
  notebooks/     the Jupyter side, run on the target
  exercises/     a stub plus a test that FAILS
  solutions/     the reference answer
  lesson.mk      kernel names, platform, block design, overlay
```

Read the README, run the worked examples, then do the exercises.

### Exercises are red-to-green

Same contract as the sibling course. Every exercise ships as a skeleton plus a
self-checking test that fails against it:

```bash
make ex L=13 E=02     # red
# ... write the kernel ...
make ex L=13 E=02     # green
```

`make solution L=13 E=02` copies the reference answer over your stub. What changes is where
the test runs. A C++ testbench on the host checks an HLS exercise, cocotb checks an
interface exercise, and `pytest` on the board over SSH checks a system exercise. Roughly one
exercise in four needs the target, and perhaps one in ten needs a full Loop C rebuild. Each
exercise's heading says which.

### Conventions

| | |
|---|---|
| HDL | Verilog-2001, as in the sibling course |
| HLS | C++17, Vitis HLS. No `#pragma` without a comment saying what it bought |
| Testbenches | C++ for HLS, cocotb for RTL, `pytest` for anything on the target |
| Notebooks | Demonstration and measurement only, never the only copy of logic |
| Test result | Every test prints a line starting `PASS` or `FAIL` |
| Constraints | Never in the RTL or the HLS, always under `boards/kv260/` |
| Block designs | Scripted Tcl, checked in. Never a saved `.bd` binary, never GUI-only steps |
| Overlays | Every lesson's bitstream is a named, versioned artifact under `overlays/` |
| Reuse | A kernel moves to `lib/` only once a *later* lesson needs it |
| Measurements | Every performance claim in a README has a reproducible command behind it |

Verilog-2001 rather than SystemVerilog keeps continuity with hello_max10. Most of the new
hardware in this course is written in C++ anyway, and part III is about why.

Scripted block designs are a necessity. A Vivado block design is the worst thing in this
ecosystem to keep in version control or explain in prose. Generating it from a Tcl script,
which then doubles as the documentation, is the only approach that stays sane.

---

## Hardware

### The board

Kria KV260 Vision AI Starter Kit: a K26 SOM (`XCK26-SFVC784-2LV-C`) on a vision carrier
card. The full reference will live in `boards/kv260/board.md`.

**Processing system**

| | |
|---|---|
| APU | 4 × Cortex-A53 @ 1,333 MHz, NEON, VFPv4, crypto extensions, 1 MB L2 |
| RPU | 2 × Cortex-R5F @ 533 MHz, lockstep or split, with TCM |
| GPU | Mali-400 MP2 @ 667 MHz |
| VCU | Hardened H.264 / H.265 encoder **and** decoder |
| DRAM | 4 GB 64-bit DDR4 with ECC |
| Storage | 16 GB eMMC, 512 Mb QSPI, microSD |

**Programmable logic**

| | |
|---|---|
| System logic cells | 256,200 |
| CLB LUTs | 117,120 |
| CLB flip-flops | 234,240 |
| DSP slices | 1,248 |
| Block RAM | 144 blocks (~5.1 Mb) |
| UltraRAM | 64 blocks (18 Mb) |
| Total on-chip SRAM | 26.6 Mb |
| Transceivers | 4 × 12.5 Gb/s GTH |

For scale, the MAX 10 in the sibling course had 8,064 logic elements and 24 multipliers.
This has roughly fourteen times the logic and fifty times the multipliers. What changes what
you can build, though, is the 4 GB of DDR4 behind an AXI interconnect.

The standard DPU configuration for this board is a single `B4096` core. If you take the
optional lesson 21, you read its utilisation report instead of trusting a number quoted
here. How much fabric a fixed neural-network accelerator eats is one of the most
instructive numbers in part V.

### The I/O budget, and the architecture it forces

This is all the general-purpose digital I/O the KV260 carrier gives you:

| Connector | What it is |
|---|---|
| **J2** | **One 12-pin Pmod with 8 PL-connected signals. That is the entire GPIO budget.** |
| J9 | Raspberry Pi *camera* connector, CSI-2, not a HAT header |
| J7 | ON Semi IAS camera, behind a dedicated AP1302 ISP |
| J8 | ON Semi IAS camera, direct |
| J5 / J6 | HDMI out / DisplayPort out |
| J10 | 1 GbE RJ-45 |
| Other | 4 × USB 3.0, microSD, PWM fan header |

Eight signals. The sibling course's pin budget table needed twenty-three, on a board that
cost a tenth as much.

AMD didn't overlook this. It is what "Vision AI Starter Kit" means. Pixels come in over MIPI
and go out over DisplayPort, and the carrier is designed for that and nothing else. It does
mean **you cannot repeat the hello_max10 actuator lessons here.** An H-bridge, a quadrature
encoder, a servo and an SPI display won't fit on eight pins, and the board you already own
handles the parts of robotics that live at the wire better anyway.

So this course reaches the physical world three ways:

1. Perception, through cameras over MIPI. The board is strong here, and part IV spends its
   time here.
2. A serial link over the one Pmod, UART or SPI, to the MAX1000 from the sibling course.
   The capstone takes this route, described below.
3. USB, for a microcontroller, a USB camera or a USB-serial adapter.

### The two-board architecture

Eight pins sounds like a limitation to work around. Treat it as a specification instead,
because it describes how real robots are built. A fast, non-deterministic perception and
planning computer talks over a link to a small deterministic device that owns the wires.

You already own the small deterministic device, and you wrote its firmware yourself.

```
         KV260                                   MAX1000
  ┌───────────────────────┐                ┌───────────────────────┐
  │ camera → PL → DPU     │   J2 Pmod      │ quad decoder          │  encoder
  │ ROS 2, planning       │ ─── UART ────→ │ fixed-point PID       │ ─── motor
  │ non-deterministic     │ ←── telemetry  │ PWM + H-bridge        │ ←── limit sw.
  │ 4× A53 @ 1.33 GHz     │                │ 12 MHz, no OS at all  │
  └───────────────────────┘                └───────────────────────┘
    hello_kria                               hello_max10 lessons 16, 17, 24
```

This costs nothing extra. It uses every actuator part the sibling course already had you
buy, and it turns lessons 16, 17 and 24 from finished exercises into a working subsystem.
The interface becomes something to study in its own right. "Can I drive a motor" stops
being the capstone's hard question, since you already did. The hard question becomes
**where the control loop belongs, and what the link between the two halves costs you.**
That is the question the whole course asks, now across two boards instead of two clock
domains.

The KV260 still has the R5F cores as a third option (part VI), so the capstone has a real
three-way choice for the inner loop: A53 under Linux, R5F on the same chip, or the MAX1000
across the link. Lesson 27 asks you to measure all three and defend one.

> **Motors get their own supply, and a common ground.** Unchanged from hello_max10, except
> the ground now spans two boards, which is one more ground loop to get wrong.

### What you'll add

| Lesson | Part | Notes |
|---|---|---|
| 01 | microSD card, 32 GB+, decent | The stock card is slow, and this is the cheapest speedup you will ever buy |
| 01 | USB-serial adapter | For the console. Don't skip it. It's how you debug a board that won't boot |
| 01 | Active cooling | The KV260 ships with a fan and heatsink. Keep them |
| 15-18 | Raspberry Pi Camera v2 / Digilent Pcam 5C | The Pcam 5C is the one the KV260 base overlay supports. Canonical's kernel also has drivers for the RPi Camera 3 (IMX708) and Global Shutter camera (IMX296) |
| 15-18 | DisplayPort or HDMI monitor | Or a capture card, if you'd rather stay headless |
| 21 (optional) | A second microSD card | For the DPU lesson on Ubuntu 22.04, so your main 24.04 card stays untouched |
| 27 | **The MAX1000 you already own** | The actuator half. Nothing new to buy |
| 27 | 4 jumper wires | J2 Pmod ↔ MAX1000 J1: TX, RX, GND, and one spare |
| 27 | External supply for actuators | Same rule as the sibling course |

Nothing else. Thanks to the two-board architecture, the KV260 side of this course needs a
card, a cable, a camera and a monitor, plus a second card if you take the optional DPU
lesson. The actuation comes from hardware already on your
desk, with working firmware on it.

---

## Toolchain and version discipline

Version mismatch costs more evenings in this ecosystem than anything else, and unlike the
sibling course's toolchain, the pieces here are not all moving in the same direction. Hence
a section of its own.

| | |
|---|---|
| Vivado / Vitis / Vitis HLS | 2026.1 |
| PetaLinux | 2026.1, only if you build images |
| Target OS | Canonical Ubuntu 24.04 LTS for Kria, supported to 2034 |
| Kernel | Canonical `linux-xilinx` 6.8 (checked at 6.8.0-1036) |
| Runtime | XRT 2.18 from the `ubuntu-xilinx/sdk` PPA, plus `pyxrt` built by `boards/kv260/os/install-pynq-noble.sh` |
| PYNQ | 3.1.2, installed by the same script |
| ROS 2 | Jazzy (supported to May 2029), with `ros2_control` and `ros2_tracing` |
| Simulation | Gazebo Harmonic, the release paired with Jazzy |
| ML | FINN + Brevitas |
| Vitis AI | Optional. The 2.5 container, for the one DPU lesson |
| Host | Ubuntu 24.04 / TUXEDO OS, x86_64 |

Six things to know before you start. Each one was checked, in September 2026, not recalled.

**Vivado's free tier still covers this board, but it now expires.** From 2026.1 AMD moved
to tiered licensing: Basic, Core, Pro, Enterprise and Gold. Kria SOMs are in the free Basic
tier, along with 7-series, Spartan and Artix UltraScale+, and selected Zynq UltraScale+
MPSoCs. The catch is that Basic is now an *annual subscription* rather than a perpetual
licence, and the tools stop working when it lapses. Put the renewal in your calendar.

**The DPU and KRS are frozen, so this course doesn't build on either.** Vitis AI 4.0 (December
2025) and 5.0 (February 2026) both say "No pre-built board image updates" for DPUCZDX8G, the
Zynq DPU. The last board setup for it is v3.0's. DPU-PYNQ was archived in August 2025, and
its runtime, `vitis-ai-runtime` 2.5, is a jammy package that needs `libpython3.10`, OpenCV
4.5 and `libprotobuf23`, so it won't install on 24.04. AMD's own KV260 docs say the Kria
accelerated apps are "not yet supported on Ubuntu 24.04". KRS needs Ubuntu 22.04, Humble and
Vitis 2022.1, and its KV260 firmware hasn't changed since November 2022. AMD's newest
robotics platform, the Kria AI SOM announced in July 2026, is x86 with no FPGA on the
module. So the DPU appears once, as an optional lesson on a spare 22.04 card, and KRS
contributes ideas rather than code.

**Kria-PYNQ's installer doesn't work on 24.04, but PYNQ does.** The installer refuses any
Ubuntu but 22.04, and patching that check isn't enough. The PYNQ 3.0.1 it installs calls
XRT's legacy `xcl*` functions, and noble's XRT 2.18 no longer exports them. PYNQ 3.1 talks
to XRT through `pyxrt` instead, which nobody packages for noble.
[`boards/kv260/os/install-pynq-noble.sh`](../boards/kv260/os/install-pynq-noble.sh) builds `pyxrt` against
noble's XRT, then installs PYNQ 3.1.2, the KV260 base overlay and the Composable Pipeline.
It also adds a `/chosen/pynq_board` node to the device tree overlay, because PYNQ 3.1 won't
believe it is on a board without one. The script passed in an emulated arm64 container on
2026-09-24. Loading a bitstream, `allocate()` and the zocl driver can only be tested on the
board, and [`boards/kv260/os/check-pynq.sh`](../boards/kv260/os/check-pynq.sh) is that test.

**Canonical's kernel has the drivers this course needs, and zocl builds against it.** The
Kria 24.04 kernel (6.8.0-1036-xilinx) builds in the IMX219 and IMX708 sensor drivers (RPi
Camera v2 and 3), the Xilinx CSI-2 receiver and ISP drivers, the ZynqMP FPGA manager, and
configfs device tree overlays. IMX296 (the RPi Global Shutter camera), OV5647, AP1302, the
R5 remoteproc driver, rpmsg and UIO ship as modules, and CMA dma-buf heaps are enabled.
There's no PREEMPT_RT, only voluntary preemption, which matters for lesson 23's jitter
numbers. XRT's zocl driver isn't in the kernel. It comes from `xrt-dkms` in the
`ubuntu-xilinx/sdk` PPA, which compiles it on the board. On 2026-09-28, `xrt-dkms` 2.18
built `zocl.ko` against the exact Kria kernel headers in an emulated arm64 container, with
matching vermagic. Whether it loads and binds on the real board is still for
`check-pynq.sh` to show.

**Start with plain overlays, and treat `.xclbin` kernels with care.** A `.bit` + `.hwh`
overlay from Vivado 2026.1 loads through the FPGA manager and doesn't care which XRT is on
the board. A `.xclbin` built with Vitis 2026.1 and run on XRT 2.18 hasn't been tested yet.
Vitis 2024.2, the release XRT 2.18 comes from, may be the safer tool for those. Lesson 04
checks both formats before the rest of the course relies on either.

**FINN is where the momentum is.** FINN released v1.0.0-alpha in September 2026 and runs its
hardware CI on the KV260 (the `KV260_SOM` target). Brevitas, PYNQ and the Vitis Libraries
all had commits the week this was checked, while Vitis AI's last was in February 2026. FINN
pins its own Vivado and Vitis HLS release through `FINN_XILINX_VERSION`, which may not be
2026.1. Check which release it wants before installing, because you may need two Vivado
installs side by side.

A `docs/versions.md` will hold the current pinned matrix, and `docs/gotchas.md` the
non-obvious behaviour, as in the sibling course.

---

# The lessons

Twenty-seven lessons in eight parts. Each depends on the ones before it.

---

## Part I. The platform

Four lessons of orientation, with no accelerator yet. The goal is to know what the machine
is, how logic gets into it while Linux is running, and how to iterate fast enough to learn
anything.

### 01. First boot

**Concepts.** What a K26 SOM is: two processor clusters, a GPU, a hardened video codec and
a fabric, all sharing one DDR controller. The boot chain, BootROM → PMU firmware → FSBL →
ATF → U-Boot → Linux, and which of those stages you will ever touch. Certified Ubuntu versus
PetaLinux, and why this course picks Ubuntu. Boot firmware versioning, and the mismatch that
produces a board that will not boot. `xmutil`, `platformstats`, `dmesg`.

**Exercises**
1. Write the Ubuntu image, get a serial console up, and log in over SSH.
2. Read the boot log and identify each stage of the chain in it.
3. Run `xmutil listapps` to see what the board shipped with, load one, and watch `dmesg`.
4. Find the SOM's part number, silicon revision and DDR size from the running system.
5. Record an idle power and thermal baseline. You will want it in part VIII.

**Board.** A Linux machine you can SSH into, with no logic of your own in it yet.

**Reference.** *Exploring Zynq MPSoC* ch. 1-2; Kria SOM wiki; UG1089.

### 02. The PS/PL boundary

**Concepts.** The Zynq UltraScale+ MPSoC IP and what configuring it means. Clocks generated
in the PS and consumed in the PL, and reset domains. EMIO versus MIO. AXI master and slave
ports (HP, HPC, LPD) and the first hint that the choice matters. Building a block design
from Tcl. Your first custom bitstream, and your first 30-minute wait.

**Exercises**
1. Script a minimal block design: PS, one clock, one reset, one AXI GPIO to the Pmod.
2. Build it. Time the build. Write the number down.
3. Toggle a Pmod pin from Linux, and verify it with a scope or an LED.
4. Read the utilisation report. You have used approximately none of the device.
5. Change one thing and rebuild, to feel what an incremental change costs.

**Board.** A pin on J2 you can wiggle from a shell.

**Reference.** *Exploring Zynq MPSoC* ch. 3-4; The Zynq Book ch. 2, 22; UG1085.

### 03. Loading logic into a running Linux

**Concepts.** Why "flash the bitstream" is the wrong mental model here. The FPGA manager.
Device tree overlays: what they are, why loading logic needs one, and how a driver finds
your IP. `/lib/firmware/xilinx/` and the shape of a Kria firmware package. The accelerated
application model with `xmutil loadapp` / `unloadapp`, `dfx-mgr`, and the DFX slots. Dynamic
Function eXchange in outline, which swaps part of the fabric while the rest keeps running.

**Exercises**
1. Package lesson 02's bitstream as a Kria app, then load and unload it.
2. Read the generated device tree overlay and map each node to something in your design.
3. Break the overlay on purpose with a wrong compatible string, and read the failure.
4. Load two apps in sequence and observe the slot behaviour.
5. Find your IP's base address three ways: Tcl, device tree, `/sys`.

**Board.** Your own logic, loaded and unloaded on a running system without a reboot.

**Reference.** Kria SOM DFX documentation; `kria-apps-firmware`; Bootlin device tree
material; UG1304.

### 04. PYNQ, and the fast loop

**Concepts.** What PYNQ is and what it is not. `Overlay()`, IP dictionaries, `MMIO`.
`allocate()` and physically contiguous memory. What sits underneath: XRT, `pyxrt`, the zocl
driver, and the device tree overlay that ties them to the PL. The install script builds
`pyxrt` and the overlay by hand, so you meet both in week one. Jupyter as a measurement
instrument. And the economics behind the whole course. An overlay swap takes two seconds
and a rebuild takes forty minutes, so structure your work to need the second one rarely.

**Exercises**
1. Run `boards/kv260/os/install-pynq-noble.sh`, reboot, then run `boards/kv260/os/check-pynq.sh` until every
   step passes.
2. Load lesson 02's overlay from a notebook and drive the Pmod from Python.
3. Print the IP dictionary and reconcile it against your Tcl.
4. Time an overlay swap and a rebuild. Put both numbers in your notes.
5. Load one design as a `.bit` + `.hwh` overlay and one as a `.xclbin` kernel, and confirm
   both run under the board's XRT 2.18. Note which Vitis release the `.xclbin` needed.
6. Write a `pytest` that runs on the target over SSH. The rest of the course uses it as its
   harness.

**Board.** Jupyter on `kria:9090`, driving your logic.

**Graduates to `lib/`.** The target-side `pytest` fixtures.

**Reference.** *Exploring Zynq MPSoC* ch. 22-24; Kria-PYNQ; PYNQ documentation.

---

## Part II. AXI

This part is about the interconnect, and nothing else in the course matters more.
Everything in a Zynq design is an AXI conversation, and every disappointing accelerator is
an AXI conversation that went badly.

### 05. Your RTL in a block design, over AXI4-Lite

**Concepts.** Packaging Verilog as an IP with IP-XACT. AXI4-Lite's five channels, the
handshake, and why a register interface is the easy case. Writing an AXI4-Lite slave by
hand, once, so the generated ones stop being magic. Address decoding and address maps.
Byte enables. The same interface generated by HLS from `s_axilite`, compared side by side.

**Exercises**
1. Take a module from hello_max10's `lib/` and package it as an IP.
2. Write an AXI4-Lite slave in Verilog exposing four registers, and verify it with cocotb.
3. Drive it from `devmem`, then from PYNQ `MMIO`.
4. Generate the equivalent with HLS `s_axilite` and diff the two interfaces.
5. Get an address wrong on purpose. See what a bus error looks like from Linux.

**Board.** Your own Verilog, in fabric, with registers Python can read.

**Graduates to `lib/`.** `axil_regs.v`

**Reference.** pp4fpgas lab *Pynq Memory Mapped IO (s_axilite)*; The Zynq Book ch. 6-7;
AMBA AXI specification; UG1037.

### 06. Interrupts

**Concepts.** The PL-to-PS interrupt path and the GIC. Level versus edge, and the
concentrator. UIO, and reaching an interrupt from userspace. PYNQ's interrupt object and
`asyncio`. Polling versus interrupts, with the crossover measured, not asserted. What an
interrupt costs you on an A53 under Linux.

**Exercises**
1. Add an interrupt output to lesson 05's IP and wire it through the concentrator.
2. Handle it via UIO in C.
3. Handle it via PYNQ and `asyncio`.
4. Measure interrupt latency and its distribution under load. The tail is the interesting
   part.
5. Find the load at which polling wins.

**Board.** Logic that tells the processor when it is done.

**Reference.** pp4fpgas lab *Interrupts*; *Exploring Zynq MPSoC* ch. 8; UG1085 ch. 13.

### 07. AXI4-Stream

**Concepts.** Ready/valid from hello_max10, now with a name and a standard. `TVALID`,
`TREADY`, `TDATA`, and the side channels `TLAST`, `TKEEP` and `TUSER`. `TLAST` marks the
packet boundary, and most bugs are about it. Backpressure across a real interconnect. Width
conversion, clock-domain crossing, and the FIFOs that do both. `hls::stream` and the `axis`
interface pragma.

**Exercises**
1. Write a pass-through stream IP in Verilog and prove `TREADY` propagates correctly.
2. Write the same in HLS with `hls::stream` and compare.
3. Get `TLAST` wrong and watch a DMA transfer hang. Diagnose it with an ILA.
4. Chain two stream stages at different widths through a converter.
5. Build a stream stage that drops data under backpressure, then fix it, as in hello_max10
   lesson 11.

**Graduates to `lib/`.** `axis_passthrough.v`, `axis_width_conv.v`

**Reference.** pp4fpgas labs *Axistream Single DMA* and *Axistream Multiple DMAs*;
AXI4-Stream specification; UG1037.

### 08. DMA and memory

**Concepts.** Full AXI4 with bursts, `AWLEN`, `ARBURST`, and why a burst of one is a
catastrophe. AXI DMA versus MCDMA versus an `m_axi` HLS master. Scatter-gather. Physically
contiguous buffers, `pynq.allocate`, and dma-buf. Cache coherency, meaning HP ports (not
coherent, flush by hand) versus HPC ports (coherent through the CCI), and the class of bug
where a stale cache line looks like broken logic.

**Exercises**
1. Move a buffer PS→PL→PS through an AXI DMA from a notebook.
2. Forget a cache flush on an HP port on purpose. Get wrong data. Understand why.
3. Repeat over an HPC port with no flush, confirm the data is correct, and measure what
   coherency costs.
4. Write an HLS kernel with an `m_axi` master reading DDR directly, and compare it against
   the DMA.
5. Measure throughput against burst length and find the knee.

**Graduates to `lib/`.** The DMA helper wrappers.

**Reference.** pp4fpgas lab *AXI4-Burst Mode (m_axi)*; *Exploring Zynq MPSoC* ch. 5-6;
UG1085 ch. 35.

### 09. Bandwidth, and the arithmetic that decides everything

**Concepts.** The DDR4 bandwidth budget, shared by four A53s, the GPU, the VCU and your
fabric. Counting bytes before writing code. Roofline, applied to this specific chip. Where
PS/PL designs bottleneck, which is almost never the compute. The AXI Performance Monitor
and ILA as measurement tools, not only debug tools.

**Exercises**
1. Compute the theoretical DDR4 bandwidth, then measure what you can get.
2. Instrument lesson 08's DMA path with an AXI Performance Monitor.
3. Build a roofline for this device and place three kernels on it.
4. Construct a case where the accelerator is faster and the *system* is slower. Explain it.
5. Write the bandwidth budget for the capstone pipeline before part IV exists.

**Board.** Measurement, not a demo.

**Reference.** CMU 18-643 (the accelerator-design framing); *Exploring Zynq MPSoC* ch. 6;
UG1145.

---

## Part III. High-level synthesis

Five lessons, and the point where the course speeds up. Everything after this part is
written in C++ unless there's a reason not to.

### 10. HLS from first principles

**Concepts.** What the tool does: scheduling and binding. Your C++ is a *specification of
behaviour*, not a description of structure. C simulation, synthesis and co-simulation, and
what each can and cannot catch. Reading the synthesis report (latency, initiation interval,
resources) and treating II as the number that matters. What does not synthesize, and why:
dynamic allocation, recursion, unbounded loops, most of the standard library.

**Exercises**
1. Write a vector add in HLS. C-sim it, synthesize it, and read every line of the report.
2. Make it 4× wider, and predict the report before you look.
3. Write something unsynthesizable on purpose and read the error.
4. Co-simulate, and find a bug C simulation could not have caught.
5. Port hello_max10's FIR filter to HLS. Compare it against the Verilog on LUTs and latency.

**Reference.** *Parallel Programming for FPGAs* ch. 1-2; UCSD CSE 237C; UG1399.

### 11. Loops, pipelines, and fixed point

**Concepts.** `PIPELINE` and initiation interval. `UNROLL`, full and partial. Loop-carried
dependencies, why they cap II, and `DEPENDENCE` for when the tool is being conservative.
Loop flattening and merging. `ap_int<>` and `ap_fixed<>`, which are hello_max10's Q-format
with the compiler doing the bookkeeping. This is where FPGAs beat CPUs, because a 12-bit
datapath costs 12 bits.

**Exercises**
1. Pipeline a loop to II=1 and explain what changed in the schedule.
2. Build a loop-carried dependency that blocks it, then restructure the loop to remove it.
3. Compare the same filter in `float`, `ap_fixed<16,4>` and `ap_fixed<8,2>` on resources,
   accuracy and f<sub>max</sub>.
4. Find the point where unrolling stops helping, and say what became the bottleneck.
5. Implement a CORDIC rotation in fixed point.

**Graduates to `lib/`.** `fir_hls.hpp`, `cordic.hpp`

**Reference.** *Parallel Programming for FPGAs* ch. 3, and its CORDIC project;
hello_max10 lessons 12-13.

### 12. Memory in HLS

**Concepts.** How arrays become memories, and how to choose between them.
`ARRAY_PARTITION` (cyclic, block, complete), `ARRAY_RESHAPE`, and `BIND_STORAGE` for BRAM
versus URAM versus LUTRAM. The 2026.1 `hls_array_partition.h` library, and why declaring
parallel access explicitly beats guessing at pragmas. Port count as the real limit on
parallelism. Line buffers and sliding windows, the structure all of part IV is built from.

**Exercises**
1. Partition an array to feed a fully unrolled loop. Watch II drop and the BRAM count rise.
2. Put a large buffer in URAM and confirm it in the report.
3. Build a 3×3 sliding window over a line buffer.
4. Use `hls_array_partition.h` for the same access pattern and compare it with the pragma
   version.
5. Create a memory port conflict, find it in the report, and fix it.

**Graduates to `lib/`.** `line_buffer.hpp`, `window.hpp`

**Reference.** *Parallel Programming for FPGAs* ch. 4; UG1399; Vitis HLS 2026.1 release
notes.

### 13. Dataflow

**Concepts.** `DATAFLOW` and task-level parallelism, meaning a chain of functions
communicating through streams, all running concurrently. Real accelerators are structured
this way, not by loop pipelining. Stream depth, and the deadlock you get when it's wrong.
Canonical form, and the rules that let the tool apply the pragma at all. Balancing stages,
which is hello_max10 lesson 13 one level up.

**Exercises**
1. Restructure a three-stage kernel into `DATAFLOW` and measure the throughput change.
2. Under-size a stream depth and deadlock it. Diagnose it from the co-sim trace.
3. Break canonical form, read the tool's refusal, and work out the rule behind it.
4. Balance an unbalanced pipeline, identifying the limiting stage first.
5. Build the capstone's preprocessing chain as a dataflow region.

**Reference.** *Parallel Programming for FPGAs* ch. 5, and its DFT/FFT projects; Cornell
ECE 6775; UG1399.

### 14. An accelerator, end to end

**Concepts.** The whole path in one lesson: HLS kernel → packaged IP → block design →
bitstream → overlay → notebook → number. Interface choice as a design decision, not a
default. Then the accounting. Speedup against one A53 core and against four with NEON,
including transfer time, the cache flush and the setup cost. This is the conversation the
course exists to prepare you for.

**Exercises**
1. Take the part III kernel through every stage to a running overlay.
2. Benchmark it against NumPy on the A53s. Report the result with and without transfer
   time.
3. Find the problem size below which the accelerator loses. Explain the shape of the curve.
4. Halve the transfer cost without touching the kernel.
5. Write the summary: what it cost in fabric, effort and watts, and what it bought. Leave
   nothing out.

**Board.** Your accelerator beating the CPU, with the receipts.

**Reference.** UCSD CSE 237C final project; CMU 18-643 project; Vitis-Tutorials.

---

## Part IV. Video

The board's reason to exist, and the four lessons hello_max10 could not have had. The
carrier traded away its GPIO for three camera connectors, two display outputs and a
hardened codec. This part spends them, and it is what makes the trade worth it.

### 15. Getting pixels in

**Concepts.** MIPI CSI-2 in outline: lanes, D-PHY, virtual channels. The AP1302 ISP on J7,
and the work an ISP does that you would otherwise have to build: demosaic, AWB, AE, gamma.
V4L2 devices and subdevices, `media-ctl`, and the media graph. Pixel formats, strides and
alignment, where the first day goes. GStreamer as plumbing.

**Exercises**
1. Attach a camera, enumerate the media graph, and draw it.
2. Capture one raw frame with `v4l2-ctl` and confirm its format and stride by hand.
3. Stream to the display with GStreamer.
4. Change resolution and frame rate, and find what the ISP will and will not negotiate.
5. Measure capture-to-display latency with a phone camera and a millisecond clock.

**Board.** A live camera on a monitor, with nothing of yours in the path yet.

**Reference.** Kria KV260 smartcam application; V4L2 API; AP1302 datasheet; *FPGA Vision
Remote Lab*.

### 16. Video in the fabric

**Concepts.** AXI4-Stream Video, with `TUSER` as start-of-frame, `TLAST` as end-of-line, and
the resync rules. Frame Buffer Read/Write, and VDMA. Lesson 12's line buffers, now
processing real pixels at real rates. Timing: pixels per second against clock frequency,
and the arithmetic that says whether your filter can keep up. Frame-rate versus line-rate
processing, and the latency difference between them.

**Exercises**
1. Insert an HLS pass-through into the live path and confirm the image survives.
2. Run a 3×3 convolution at full frame rate, and check the timing arithmetic against the
   report.
3. Handle the frame boundary correctly, then get it wrong and see the tearing.
4. Compare a line-rate filter against one that buffers whole frames, in latency.
5. Run the same convolution on the A53s and compare frames per second.

**Graduates to `lib/`.** `video_passthrough.hpp`, `conv3x3.hpp`

**Reference.** *FPGA Vision Remote Lab* lectures; UG934; PYNQ Composable Pipeline.

### 17. The Vitis Vision Library

**Concepts.** `xf::cv`, OpenCV's interface with an FPGA behind it. The L1/L2/L3 structure
and which level to use when. Windowed, streaming, integer work is cheap in fabric. Global,
iterative, floating-point work is expensive. That rule is more useful than any function
list. Composing library functions without a round trip to DDR between each one.

**Exercises**
1. Build an `xf::cv::resize` at L1 and check it against OpenCV bit for bit.
2. Chain colour conversion → Sobel → threshold in one dataflow region.
3. Compare that chain against three separate accelerators, in DDR traffic and latency.
4. Profile a library function against your own lesson 16 convolution, and report which
   wins even if it's the library.
5. Find a function whose FPGA implementation loses to the A53s, and say why.

**Reference.** Vitis Vision Library documentation; Vitis_Libraries repository.

### 18. Pixels out, and the video codec

**Concepts.** DisplayPort and HDMI output paths, and the DP live interface that lets the
fabric feed the display controller directly. The VCU, a hardened H.264/H.265 encoder and
decoder that costs no fabric at all, and the most underused block on the chip. Encoding,
streaming over the network, and the end-to-end latency budget of a real robot's video link.
Where the VCU beats doing the same job in PL, which is nearly always.

**Exercises**
1. Output a fabric-generated test pattern over DisplayPort.
2. Encode the camera to H.265 with the VCU and measure the fabric cost. It is zero.
3. Stream it over the network and measure glass-to-glass latency.
4. Tune the encoder for latency instead of quality, and measure the trade.
5. Build the full budget in milliseconds: sensor → ISP → PL → VCU → network → display.

**Board.** A low-latency video link off the board, with your processing in it.

**Reference.** UG1085 ch. 34; VCU documentation (PG252); Kria smartcam.

---

## Part V. Machine learning in the fabric

Four lessons, one of them optional. A fast classifier is not the goal. The goal is to see
how a network becomes hardware, well enough to decide whether it belongs in fabric at all.
FINN is the main path, because it is maintained and it teaches the most. The DPU appears
once, as the fixed-accelerator comparison, on a spare SD card.

### 19. Quantisation

**Concepts.** Why INT8 and not float: the arithmetic, the memory bandwidth, the DSP
utilisation. Symmetric versus asymmetric, per-tensor versus per-channel. Post-training
quantisation and calibration, and what those ~500 images are computing. QAT, and when PTQ
is not enough. Brevitas as the main tool, since FINN consumes its output directly. Where
accuracy goes, measured instead of assumed.

**Exercises**
1. Quantise a small classifier to INT8 with PTQ in Brevitas and measure the accuracy delta.
2. Vary the calibration set size and plot accuracy against it.
3. Find a layer that quantises badly, and explain what in its distribution caused it.
4. QAT the same network in Brevitas on the host GPU and compare it against PTQ.
5. Compute the theoretical bandwidth saving, then measure the real one.

**Board.** Host-side, but the numbers drive lessons 20-22.

**Reference.** Brevitas documentation; *Exploring Zynq MPSoC* ch. 25; the Vitis AI
quantiser documentation if you take lesson 21.

### 20. The FINN path

**Concepts.** FINN compiles *this* network into *its own* dataflow architecture, one layer
of hardware per layer of network. Brevitas for quantisation-aware training below 8 bits.
Folding as the throughput/resource dial. Why sub-8-bit works in a dataflow design. The
price is one bitstream per network, and a real build each time. FINN's generated PYNQ
driver, and the thin C++ or Python API you put around it so lesson 26 can call it from a
ROS 2 node.

**Exercises**
1. Train a small quantised network in Brevitas on the host GPU.
2. Compile it through FINN to a bitstream for `KV260_SOM`, reading the estimate reports
   first.
3. Change the folding factors and plot throughput against LUTs.
4. Take it below 8 bits, to 4, 2 and 1, and measure accuracy against resources.
5. Run it on the board through FINN's driver, then wrap it in an API with fixed input and
   output buffers allocated once.

**Board.** A quantised network running in fabric, called through your own API.

**Graduates to `lib/`.** The FINN driver wrapper.

**Reference.** FINN documentation; Brevitas; *Benchmarking QNNs on FPGAs with FINN*
(arXiv:2102.01341).

### 21. The DPU path (optional)

**Concepts.** DPUCZDX8G as a *fixed* accelerator: one overlay, many networks, configured at
build time and loaded like any other IP. `B4096` on this device, and what its utilisation
report says. `vai_c_xir`, `arch.json`, and the `DPUCZDX8G_ISA1_B4096` fingerprint. Subgraph
partitioning, which decides what the DPU takes and what falls back to the ARM cores. VART
and the Vitis AI runtime. And version discipline, on purpose. The DPU runtime only exists
for Ubuntu 22.04, so this lesson runs from a second microSD card with the stock 22.04 image,
Kria-PYNQ and DPU-PYNQ. Models compile with the Vitis AI 2.5 container
(`xilinx/vitis-ai-cpu:2.5`) to match the board's VART 2.5.

**Exercises**
1. Boot the 22.04 card and install Kria-PYNQ and DPU-PYNQ with their stock installers.
2. Compile a model for `DPUCZDX8G_ISA1_B4096` with the 2.5 container and read the
   compiler's subgraph report.
3. Run it on the board and measure frame rate and latency at batch size 1.
4. Compile the same model with the 3.5 container and watch it fail to load. That is the
   trap, defused.
5. Read the DPU's utilisation report and state how much fabric it leaves for part IV's
   pipeline.

**Board.** Live camera classification on the side card, at a frame rate you measured.

**Reference.** Vitis AI 2.5 and 3.5 documentation; DPU-PYNQ (archived); PG338.

### 22. Choosing

**Concepts.** The judgement lesson. A FINN network, a classical Vitis Vision pipeline with no
network at all, and the CPU (NEON, or ONNX Runtime on the A53s), plus the DPU if you took
lesson 21. Compared on the axes that decide real projects: latency, throughput, resources,
power, accuracy, build time, maintenance, and how much fabric is left for everything else.
Batch size one, the only batch size a robot has. For a lot of robot perception, a classical
pipeline in fabric beats any network on latency and power, and this lesson makes you check.

**Exercises**
1. Pick one robot task, such as finding a coloured marker or a line. Benchmark every path
   on it with one metric definition, and publish the harness.
2. Compare at batch size 1 specifically, and explain the difference from batch 8.
3. Add the CPU baseline. Keep it in the table even when it's embarrassing.
4. Measure power for each path at the wall.
5. Write the decision memo: which one goes into the capstone, and why.

**Board.** A benchmark table you would be willing to defend.

**Reference.** Lessons 17, 20 and 21; ASU ARC 2025 *Out-of-the-Box Performance of FPGAs for
ML Workloads Using Vitis AI*.

---

## Part VI. Real time

Two lessons on the part of the chip that exists because Linux cannot promise you anything.
Robotics control loops belong here, and this is the strongest argument for this class of
device over a GPU module.

### 23. The R5F cores

**Concepts.** The RPU: two Cortex-R5F cores, split or lockstep, with tightly coupled memory
and no MMU. Bare metal and FreeRTOS. Why a control loop on an R5F is deterministic and the
same loop on an A53 under Linux is not, because of caches, the scheduler, interrupts, other
cores and thermal throttling. TCM is what makes it predictable. Jitter is the only
comparison that means anything, so you measure it.

**Exercises**
1. Build and run a bare-metal application on R5-0.
2. Run a 10 kHz timer loop on the R5F and measure period jitter on a pin.
3. Run the same loop as a Linux userspace thread and measure its jitter.
4. Repeat with `SCHED_FIFO`, and `PREEMPT_RT` if available. Plot all three distributions.
5. Move the loop's working set out of TCM and measure what that costs.

**Board.** Two histograms that make the argument better than any paragraph.

**Reference.** *Exploring Zynq MPSoC* ch. 2, 9; UG1085 ch. 4; FreeRTOS on R5;
Buttazzo, *Hard Real-Time Computing Systems* ch. 1-2.

### 24. OpenAMP and the three-way split

**Concepts.** Linux on the A53s, an RTOS on an R5F and logic in the fabric, all at once, and
the plumbing between them. OpenAMP, `remoteproc`, `rpmsg`, and shared memory. Partitioning
a robot, with perception on Linux, the inner loop on the R5F, and the streaming datapath in
fabric. Who owns which memory, and what happens when two masters disagree.

**Exercises**
1. Bring up an OpenAMP echo between Linux and R5-0.
2. Pass setpoints down and telemetry up over `rpmsg`, and measure round-trip latency.
3. Give the R5F direct access to an AXI peripheral in the PL, keeping Linux out of the
   path.
4. Share a buffer three ways without corrupting it. Get the cache maintenance right.
5. Draw your capstone's partition and justify every boundary.

**Graduates to `lib/`.** The `rpmsg` telemetry channel.

**Reference.** UG1186; Multi-OS Support wiki; `OpenAMP_tests`; Antmicro's Zephyr-on-R5
write-up.

---

## Part VII. ROS 2

Two lessons connecting all of the above to ROS 2 Jazzy.

### What this course borrows from KRS

AMD's Kria Robotics Stack (KRS) officially supports the KV260, but it is frozen at Ubuntu
22.04, ROS 2 Humble and Vitis 2022.1. Its KV260 firmware package hasn't changed since
November 2022, and the repository's only 2026 commit is a README wording change. This course
doesn't install it. It takes four of its ideas and builds them on Jazzy with XRT:

| KRS idea | This course's version | Lesson |
|---|---|---|
| An accelerated node: a ROS 2 component calling a PL kernel | An `rclcpp` component calling the XRT C++ API (`xrt::kernel`, `xrt::bo`), or PYNQ from Python | 26 |
| The adaptive component, switching a node between CPU and FPGA at runtime | A parameter that switches the same component to its CPU path | 26 |
| AXI4-Stream between adjacent accelerated nodes, so they skip DDS | Kernels fused in one overlay, with one node on the outside | 26 |
| `colcon-acceleration` build glue | Plain `colcon`, in a Jazzy arm64 container on the host or natively on the board | 25 |

### 25. ROS 2 on the board

**Concepts.** Ubuntu 24.04 and ROS 2 Jazzy on the A53s. Nodes, topics, executors and QoS.
DDS on a four-core embedded target, which is not free. Building for arm64, either natively
on the board or in a Jazzy arm64 container on the host. `ros2_tracing` and LTTng for seeing
where time goes. A camera publisher and an image consumer. The baseline everything in
lesson 26 is measured against, because "we accelerated it" means nothing without one.

**Exercises**
1. Install ROS 2 Jazzy, run talker/listener, and measure the CPU cost.
2. Set up the host-side arm64 build container, and time a workspace build there against
   the same build on the board.
3. Publish the lesson 15 camera as `sensor_msgs/Image`, and write a subscriber that does the
   lesson 16 convolution in OpenCV on the CPU.
4. Vary QoS and message size, and find where DDS starts to hurt.
5. Trace the pipeline with `ros2_tracing`, and identify the top three costs before you
   accelerate anything.

**Board.** A working, unaccelerated, fully measured ROS 2 vision pipeline.

**Reference.** ROS 2 Jazzy documentation; `ros2_tracing`; KRS documentation (for concepts);
`acceleration_examples`.

### 26. Accelerating a ROS 2 node

**Concepts.** The accelerated-node template this course uses from here on: an `rclcpp`
component, XRT buffers allocated once, zero-copy with dma-buf and loaned messages, and a
`use_fpga` parameter that falls back to the CPU path at runtime. The copies you didn't know
you had, in DDS serialisation, executor hand-offs, and the trip through DDR. Intra-process
composition, and why it matters more than the accelerator does. Fusing adjacent kernels over
AXI4-Stream inside one overlay, so they never touch DDS. Measuring end to end, not kernel to
kernel.

**Exercises**
1. Build the template around lesson 16's convolution, and switch `use_fpga` on and off
   while the pipeline runs.
2. Count the copies in that path, then remove one with dma-buf and loaned messages.
3. Compose two nodes intra-process and measure the difference.
4. Fuse two adjacent accelerators in one overlay behind one node, and compare against two
   separate nodes.
5. Put lesson 20's FINN network behind the same template. Report the end-to-end speedup and
   the CPU time freed, even if one of them disappoints.

**Board.** An accelerated ROS 2 pipeline, with a latency budget you can account for line by
line.

**Graduates to `lib/`.** The accelerated-node template.

**Reference.** XRT native C++ API documentation; ROS 2 composition and loaned-message
documentation; `ros2_tracing`; KRS *Accelerated ROS 2 publisher* (for concepts).

---

## Part VIII. Capstone

### 27. Perception to action

Everything, at once.

**Concepts.** A robot as a latency budget. Where each stage runs, and why. Graceful
degradation when a stage overruns. Telemetry as the main debugging tool. `ros2_control` as
the boundary between planning and actuation. And the partition, decided by measurement,
which is the entire course in one deliverable.

Both courses run at once, on two boards, over four wires.

**Deliverables**
1. Camera → accelerated preprocessing in PL → perception (FINN or a classical pipeline, your
   lesson 22 choice) → decision, running at a stated and measured frame rate.
2. A `ros2_control` hardware interface for the MAX1000. Underneath it, a framed, checksummed
   setpoint/telemetry protocol over the J2 Pmod, and hello_max10's own lessons 16, 17 and 24
   closing the motor loop. Handle a dropped frame and a dead link without hurting the
   hardware.
3. **The inner-loop decision, measured three ways**: A53 under Linux, R5F on the same die,
   and the MAX1000 across the link. Jitter histograms for all three. Pick one and defend it.
4. The same robot in Gazebo Harmonic first, driven by the same `ros2_control` controllers,
   then on the hardware. Record a bag of both.
5. A full latency budget, photon to torque, with every stage measured and attributed. That
   includes the serial link, which will cost more than you assumed.
6. A resource and power report, and one paragraph on what you would do differently.

**Reference.** All of it, from both courses; `ros2_control` and Gazebo Harmonic
documentation.

---

## Pacing

Rough, assuming evenings. Unlike the sibling course, the early parts are the slow ones,
because the tooling gets in the way before the concepts do.

| Part | Lessons | Effort |
|---|---|---|
| I. The platform | 01-04 | A week each, mostly fighting the toolchain |
| II. AXI | 05-09 | Half a week to a week each |
| III. HLS | 10-14 | A week each, longer for 13 and 14 |
| IV. Video | 15-18 | One to two weeks each. 15 is the hardest lesson in the course |
| V. Machine learning | 19-22 | A week each for 19, 20 and 22, plus one long FINN build. 21 is optional |
| VI. Real time | 23-24 | A week each |
| VII. ROS 2 | 25-26 | A week for 25, two for 26 |
| VIII. Capstone | 27 | As long as it takes |

Call it eight to ten months of evenings, against six for hello_max10. The concepts are
mostly no harder. A forty-minute build punishes guessing, though, and part I is a tooling
slog that no amount of good writing makes short.

If you need a shorter path, the spine is **01-14 plus 27**: the platform, AXI, HLS, and a
capstone that skips inference. That is the core that transfers to other boards, and it
takes roughly four months. Parts V, VI and VII are the most self-contained and can be added
in any order once part III is done.

The lesson most likely to make you want to stop is **15**. Camera bring-up on this platform
is unpleasant for everyone. When it goes badly, blame the ecosystem before yourself.

---

## References

### Courses this draws on

- **UC San Diego CSE 237C, Hardware Design**
  <https://kastner.ucsd.edu/ryan/cse237c/> · Ryan Kastner. Projects and labs at
  <https://pp4fpgas.readthedocs.io/>.
  The primary source for part III, and the closest thing to a canonical HLS course. Part II
  follows its lab sequence almost line for line, because the ordering is right:
  `s_axilite` → AXI-Stream with one DMA → multiple DMAs → `m_axi` bursts → interrupts.
  Project sequence: FIR → CORDIC → phase detector → DFT → FFT → OFDM receiver → BNN.

- **Cornell ECE 6775 (formerly 5775), High-Level Digital Design Automation**
  <https://www.csl.cornell.edu/courses/ece6775/> · Zhiru Zhang.
  The theory under part III. It treats scheduling, binding, pipelining and resource sharing
  as compiler problems rather than pragmas. Also the source of part V's framing of
  deep-learning accelerators. Uses the same Kastner textbook.

- **Carnegie Mellon 18-643, Reconfigurable Logic: Technology, Architecture and
  Applications**
  <https://courses.ece.cmu.edu/18643> · James C. Hoe.
  The systems-level view behind lesson 09 and the course's "measure it or it didn't happen"
  rule. It requires prior RTL experience, the same relationship this course has with
  hello_max10. Has a substantial acceleration project.

- **Hochschule Bonn-Rhein-Sieg FPGA Vision Remote Lab / FPGA Vision Open Online Course**
  <https://www.h-brs.de/en/fpga-vision-open-online-course> ·
  <https://www.h-brs.de/en/fpga-vision-remote-lab> · Marco Winzker.
  Free and open, and the best-structured material I found on FPGA image processing. The
  direct source for part IV, and the reason lesson 16 is organised around line-rate rather
  than frame-rate processing.

- **ETH Zürich Digital Design and Computer Architecture**
  <https://safari.ethz.ch/ddca/> · Onur Mutlu.
  Already the theory spine of hello_max10. Here it is background, worth revisiting for the
  memory-system material behind lessons 08-09.

- **UC Berkeley EECS 151/251A** and **MIT 6.205**. The sources of hello_max10's arc, listed
  here for continuity. Neither targets a heterogeneous SoC, and that is the gap this course
  fills.

- **AMD University Program, Vivado embedded design flow / advanced embedded design (Zynq)**
  <https://www.amd.com/en/corporate/university-program.html>
  Two-day workshop material. It's not a course and it's vendor-flavoured, but the
  block-design and custom-peripheral labs are the fastest route through part II's mechanics.

### Books

- **Crockett, Northcote & Ramsay, *Exploring Zynq MPSoC: With PYNQ and Machine Learning
  Applications***. Strathclyde Academic Media, 2019. Free PDF at
  <https://www.zynqbook.com/>.
  The most important book for this course, and the closest thing to *DDCA* for this device.
  It covers Zynq UltraScale+ MPSoC, the same silicon family as the K26, and it covers PYNQ
  and ML acceleration directly.

  | Chapter | Topic | Our lessons |
  |---|---|---|
  | 1-2 | Introduction, MPSoC architecture | 01, 23 |
  | 3-4 | Design flow, system design | 02 |
  | 5-6 | Memory, interconnect | 08, 09 |
  | 7-9 | Peripherals, interrupts, RPU | 06, 23 |
  | 22-24 | PYNQ | 04 |
  | 25 | Machine learning | 19-22 |

  It dates from 2019, so the screenshots show Vivado 2018-era tools. The architecture is
  unchanged but the GUI is not. Read it for the concepts and skip the click-paths, which is
  one more argument for this course's scripted-Tcl convention.

- **Crockett, Elliot, Enderwitz & Stewart, *The Zynq Book*** and ***The Zynq Book
  Tutorials***. Free PDF at <https://www.zynqbook.com/>.
  Zynq-7000, so a generation behind and no longer maintained. It still has the clearest
  explanation of AXI and of the PS/PL boundary in print, and it is easier going than the
  AMBA specification. Use it for part II's concepts, not its tool flows.

- **Kastner, Matai & Neuendorffer, *Parallel Programming for FPGAs***. Free at
  <https://kastner.ucsd.edu/hlsbook/>, source at
  <https://github.com/KastnerRG/pp4fpgas>.
  The textbook for part III, and the reason part III has five lessons instead of two. Its
  chapters map unusually tightly onto its projects, and the projects are good.

  | Chapter | Topic | Our lessons |
  |---|---|---|
  | 1-2 | Introduction, HLS basics | 10 |
  | 3 | Loops, pipelining, CORDIC | 11 |
  | 4 | Memory, partitioning | 12 |
  | 5 | Dataflow, DFT/FFT | 13 |
  | 6+ | Projects | 14 |

- **Harris & Harris, *Digital Design and Computer Architecture*, RISC-V Edition**.
  The prerequisite's book. Referenced here only where a lesson leans on something from
  hello_max10.

- **Vasquez & Simmonds, *Mastering Embedded Linux Development*** (4th edition of *Mastering
  Embedded Linux Programming*, 2025), <https://www.packtpub.com/>.
  For part I and lesson 03: device tree, boot, `systemd`, Yocto. It isn't Zynq-specific, and
  that's why it's here. The Kria material assumes you know this and never teaches it.

- **Buttazzo, *Hard Real-Time Computing Systems***, for part VI. You need the first two
  chapters and the scheduling material. The rest goes beyond what this course uses.

- **Lynch & Park, *Modern Robotics***, <http://modernrobotics.org> (free PDF).
  Not an FPGA book at all. It's here because the capstone is a robotics problem, and the
  kinematics and control it needs are in this book and nowhere else on the list.

### Free training material

- **Bootlin**, <https://bootlin.com/docs/>, all slides and labs CC-BY-SA.
  Embedded Linux, kernel and driver development, device tree, Yocto. Their *Device Tree 101*
  material is the best free explanation of what lesson 03 depends on.

### Specifications and datasheets

Fetch these as the lessons need them, not before.

- **UG1085**, *Zynq UltraScale+ Device Technical Reference Manual*. The 1,200-page one. You
  will read chapters 4 (RPU), 13 (interrupts), 34 (DisplayPort) and 35 (interconnect), and
  nothing else.
- **UG1089**, *Kria KV260 Vision AI Starter Kit User Guide*. The carrier card: connectors,
  the J2 Pmod pinout, power.
- **K26 SOM Data Sheet (DS987)** and **KV260 Data Sheet (DS986)**. Device resources, tool
  support, electrical characteristics.
- **UG1399**, *Vitis HLS User Guide*. Part III's reference manual. You will live in the
  pragma chapter.
- **UG1037**, *AXI Reference Guide*, and Arm's **AMBA AXI and AXI4-Stream specifications**.
  Lesson 07 needs the stream one specifically.
- **PG338**, *DPUCZDX8G Product Guide*, for the optional lesson 21.
- **PG252**, *VCU Product Guide*, for lesson 18.
- **UG1186**, *Libmetal and OpenAMP User Guide*, for lesson 24.

### Tools and repositories

- **Vivado / Vitis / Vitis HLS 2026.1**. Kria SOMs are in the free Basic tier. Renew
  annually.
- **Canonical Ubuntu 24.04 LTS for Kria**, <https://ubuntu.com/download/amd>. The Server
  image, supported to 2034.
- **XRT**, <https://github.com/Xilinx/XRT>. Very active. The native C++ API (`xrt::device`,
  `xrt::kernel`, `xrt::bo`) is what lesson 26's node template calls.
- **Kria-PYNQ**, <https://github.com/Xilinx/Kria-PYNQ>. Last commit March 2026. Its
  installer only accepts Ubuntu 22.04, so `boards/kv260/os/install-pynq-noble.sh` takes three pieces
  from it instead: `libcma`, the device tree fragment, and the base overlay, which supports
  the Pcam 5C and the J2 Pmod.
- **PYNQ**, <https://github.com/Xilinx/PYNQ>. 3.1.2 on PyPI, which uses `pyxrt`. The
  `pynq-next` branch moved to Noble and AMD EDF 2025.2 in August 2026, but only for ZCU104 and
  VCK190 so far. Watch it for Kria support.
- **kria-vitis-platforms**, <https://github.com/Xilinx/kria-vitis-platforms>. Active. The
  reference platforms, including smartcam.
- **kria-apps-docs**, <https://xilinx.github.io/kria-apps-docs/>. The DFX and accelerated
  application model, for lesson 03.
- **Vitis_Libraries**, <https://github.com/Xilinx/Vitis_Libraries>. Active. `vision/` is the
  part IV material.
- **FINN** and **Brevitas**, <https://github.com/Xilinx/finn> and
  <https://github.com/Xilinx/brevitas>. Both very active. FINN v1.0.0-alpha shipped in
  September 2026, with hardware CI on the KV260.
- **Vitis-AI**, <https://github.com/Xilinx/Vitis-AI>. Optional, for lesson 21 only. Use the
  2.5 container (`xilinx/vitis-ai-cpu:2.5`, still on Docker Hub) to match the board's VART
  2.5. Releases 4.0 and 5.0 have no Zynq DPU updates.
- **DPU-PYNQ**, <https://github.com/Xilinx/DPU-PYNQ>. Archived in August 2025. It still
  installs with Kria-PYNQ on Ubuntu 22.04, which is how lesson 21 uses it.
- **KRS**, <https://github.com/Xilinx/KRS>. The KV260 is in its full-support tier, but
  `acceleration_firmware_kv260` has been untouched since November 2022 and the stack wants
  Vitis 2022.1, Ubuntu 22.04 and Humble. Ideas only, see part VII.
- **ros-acceleration/acceleration_examples**,
  <https://github.com/ros-acceleration/acceleration_examples>. The most active part of that
  org (last commit May 2025), and the most useful thing in it for lesson 26.
- **ROS 2 Jazzy**, <https://docs.ros.org/en/jazzy/>. Supported to May 2029.
- **ros2_control**, <https://control.ros.org/jazzy/>. The hardware-interface layer the
  capstone's MAX1000 link plugs into.
- **ros2_tracing**, <https://github.com/ros2/ros2_tracing>. LTTng-based tracing for lessons
  25-27.
- **Gazebo Harmonic**, <https://gazebosim.org/docs/harmonic/>. The simulator paired with
  Jazzy, for the capstone's simulation run.
- **cocotb**, **Icarus Verilog**, **GTKWave**. Unchanged from hello_max10, and still used
  for the RTL that remains.

Setup will be in `docs/00-setup.md`, the loops in `docs/01-workflow.md`, the pinned tool
matrix in `docs/versions.md`, and non-obvious behaviour in `docs/gotchas.md`.
