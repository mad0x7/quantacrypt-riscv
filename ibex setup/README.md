# Ibex setup — Arty A7-100T

FPGA bring-up for QuantaCrypt, contributed by
**[shaunakg08s](https://github.com/shaunakg08s)**.

This package connects the lowRISC Ibex RISC-V CPU to 64 KiB of block RAM,
four LEDs, and a transmit-only UART on the Digilent Arty A7-100T. It includes
bare-metal firmware, board constraints, a Verilator regression, and a
reproducible Vivado build entry point.

The current firmware tests RAM and GPIO, prints a startup message, and cycles
the LEDs. This is a board bring-up platform. It does not yet integrate the
repository's ML-DSA software, NTT accelerator, or a secure-boot chain.

## Package layout

| Path | Purpose |
| --- | --- |
| `rtl/ibex_minimal_soc.sv` | Ibex integration, 64 KiB RAM, GPIO and UART registers |
| `rtl/arty_top.sv` | Board wrapper, 100 MHz to 50 MHz clocking and reset synchronization |
| `rtl/uart_tx.sv` | 115200 baud UART transmitter |
| `constraints/arty_a7_100.xdc` | Arty A7-100T pin assignments and clock constraint |
| `sw/` | Firmware, startup code, memory map and linker script |
| `sim/sim_main.cpp` | Two-boot system regression and UART receiver |
| `tools/` | Dependency fetch, firmware build and FPGA/simulation build scripts |
| `minimal_soc.core` | FuseSoC source lists and simulation/FPGA targets |
| `dependencies.json` | Exact upstream Ibex revision |
| `requirements.txt` | Tested FuseSoC and Edalize versions |
| `docs/` | Hardware interface and verification details |
| `third_party/` | Upstream attribution and downloaded dependencies |

## Requirements

Use Linux or WSL for simulation and firmware development. Programming the
board from WSL additionally requires USB access. The FPGA build requires a
working Vivado installation with Artix-7 support.

Tested tools:

- Python 3.11, Git, GNU Make, and a C++ compiler.
- FuseSoC 2.4.3 and Edalize 0.6.8.
- Verilator 5.032.
- lowRISC toolchain `rv32imcb-x86_64-20260913-1`, with Clang 22.1.7.
- Vivado 2026.1 for FPGA synthesis and implementation.

A RISC-V bare-metal GCC toolchain can also be selected by the build scripts;
the recorded firmware validation uses the lowRISC Clang toolchain.

## Set up

From a clone of this repository:

```sh
cd "ibex setup"
python3 -m venv .venv
. .venv/bin/activate
python3 -m pip install -r requirements.txt
make dependencies
```

For the separate Desktop copy, start with `cd "$HOME/Desktop/ibex setup"`.
Always quote the folder path because its name contains a space.

Download and extract a RISC-V bare-metal toolchain from the
[lowRISC releases](https://github.com/lowRISC/lowrisc-toolchains/releases),
then point the build at its `bin` directory:

```sh
export IBEX_TOOLCHAIN_BIN="/path/to/lowrisc-toolchain/bin"
```

Alternatively, put `riscv32-unknown-elf-gcc` or `riscv64-unknown-elf-gcc`,
with matching `objcopy`, on `PATH`. The firmware build explicitly targets
`rv32imc_zicsr` with the `ilp32` ABI.

To reuse an existing Ibex checkout, set `IBEX_ROOT` to it instead of running
`make dependencies`. It must match the revision in `dependencies.json`.
To reuse FuseSoC from an existing Python environment, set `FUSESOC` to that
environment's `bin/fusesoc` executable or activate the environment first.

## Build and simulate

```sh
make firmware
make simulate
```

The simulation checks two boots, including a reset that retains RAM contents.
Successful output ends with:

```text
PASS: two successful Ibex boots, including reset with retained RAM.
```

The firmware build creates an ELF, raw binary, linker map, and a complete
64 KiB memory initialization file. These generated files are not committed.

The scripts print the output locations. Generated tool projects and memory
images use a separate build directory without spaces because the FPGA tools
do not reliably quote memory-file parameters. To keep outputs at a persistent
location of your choice, set a path containing only letters, digits, `_`,
`-`, `.`, and `/`:

```sh
export BUILD_ROOT="$HOME/quantacrypt-build/ibex"
```

Without `BUILD_ROOT`, each copy of this setup uses its own directory under the
system temporary directory. Temporary outputs may be removed by the OS.
Simulation and FPGA builds have separate output directories.

## Build and program the FPGA

Make Vivado available on `PATH`, normally by sourcing its `settings64.sh`,
then run:

```sh
make bitstream
```

The target device is **`xc7a100tcsg324-1` (Arty A7-100T)**. A 35T board needs
its own device configuration; do not use this bitstream on it.

The script prints the generated `.bit` path. In Vivado Hardware Manager:

1. Connect and power the board using its programming USB port.
2. Open the target and connect to the detected FPGA.
3. Choose **Program Device** and select the printed `.bit` file.
4. Open the board's USB serial port at **115200 baud, 8 data bits, no parity,
   one stop bit, no flow control**, then press RESET.

Expected firmware output is:

```text
Ibex minimal SoC alive
RAM and GPIO test: PASS
tick
```

The four LEDs cycle through one-hot patterns. An all-on pattern indicates a
firmware failure or trap. UART is transmit-only in this setup.

See [verification details](docs/VERIFICATION.md) for what has actually been
checked, and [hardware interface](docs/HARDWARE.md) for the memory map and pins.

## Attribution and scope

The board integration, constraints, firmware, and simulation harness were
collected from shaunakg08s's FPGA bring-up work. Packaging adds portable build
paths, a pinned dependency fetch, and these setup instructions.

The CPU is upstream lowRISC Ibex; see [third-party attribution](third_party/README.md).
The earlier counter-only Vivado project and 35T Arty experiment are not part
of this 100T build. The Vivado project for this design is generated from
`minimal_soc.core`, so a machine-specific `.xpr` file is not required.
