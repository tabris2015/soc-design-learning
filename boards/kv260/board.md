# AMD Kria KV260

Not yet tested on hardware. Everything below was checked offline, in September 2026.

## Specs

| Block | |
|---|---|
| SOM | Kria K26, Zynq UltraScale+ `XCK26`, 256K system logic cells |
| Processor | 4× Cortex-A53, 2× Cortex-R5F, Mali-400 GPU |
| Memory | 4 GB DDR4, shared by the processors and the fabric |
| Fabric I/O on the carrier | one Pmod (8 pins), camera connectors, DisplayPort, HDMI |
| Toolchain | Vivado 2026.1, free Basic tier, renewed yearly |

## Board OS

Canonical's Ubuntu 24.04 for Kria, supported until 2034, with the `linux-xilinx` 6.8
kernel and XRT 2.18 from the `ubuntu-xilinx/sdk` PPA.

[os/install-pynq-noble.sh](os/install-pynq-noble.sh) installs PYNQ 3.1.2 on it, which
Kria-PYNQ's own installer can't do. Copy `os/` to the board and run it as root, then
`os/check-pynq.sh` to test loading an overlay, allocating buffers, register access and
Jupyter.

| | Status |
|---|---|
| PYNQ install | passes in an emulated arm64 Ubuntu 24.04 container, up to the steps that need the board |
| zocl from `xrt-dkms` | builds against the Kria 24.04 kernel headers, with matching vermagic. Not yet loaded |
| `.bit` overlays through the FPGA manager | expected to work, untested |
| `.xclbin` from Vitis 2026.1 on XRT 2.18 | untested |

[docs/kv260-draft-syllabus.md](../../docs/kv260-draft-syllabus.md) holds the research
behind these choices: licensing, the frozen DPU and KRS stacks, kernel drivers, FINN.
