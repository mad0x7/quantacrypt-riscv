# Verification record

Validated on **15 November 2026**, from the packaged source directory named
`ibex setup`, with the exact upstream Ibex revision in `dependencies.json`.
The local RTL, constraints, firmware and simulation harness match the original
100T bring-up sources; the packaging changes affect setup and build paths.

## Checks performed

| Check | Result |
| --- | --- |
| Fetch the pinned Ibex revision from GitHub | Passed; checkout at `af456e25575013668ab56725268126f6b0feca35` |
| Repeat dependency setup | Passed; existing matching checkout reused |
| Install `requirements.txt` in a new Python 3.11 environment inside `ibex setup/.venv` | Passed |
| Build board firmware | Passed; 968 initialized bytes, ELF entry `0x80` |
| Build simulation firmware | Passed; 964 initialized bytes, ELF entry `0x80` |
| Generate RAM images | Passed; 16,384 32-bit words, covering 64 KiB |
| Verilator regression using the downloaded dependency and new environment | Passed; both boots completed after 309,382 clocks each |
| Reuse an external pinned Ibex checkout and FuseSoC environment | Passed |
| Reject unsupported build-output paths | Passed; whitespace and special characters are rejected before tool invocation |
| Vivado synthesis, implementation and bitstream generation | Passed for `xc7a100tcsg324-1` with Vivado 2026.1 |

The Vivado run used the previously installed FuseSoC 2.4.3 / Edalize 0.6.8
environment. The final simulation also verified those versions in the newly
created environment under the folder containing a space. Both used the
lowRISC `rv32imcb-x86_64-20260913-1` toolchain (Clang 22.1.7).

## Simulation coverage

The harness runs the same CPU model through two resets, retaining RAM between
boots. It checks reset output states, UART framing and expected messages,
firmware failure/trap indication, all four LED patterns, and a timeout.

The firmware checks initialized data, BSS clearing, RAM word reads and writes,
byte and halfword stores, and GPIO readback. Simulation reduces the LED delay
through `BLINK_CYCLES`; the FPGA firmware uses the board timing.

Final output:

```text
Boot 1 passed after 309382 clocks: UART framing, firmware RAM/GPIO checks, LED sequence.
Boot 2 passed after 309382 clocks: UART framing, firmware RAM/GPIO checks, LED sequence.
PASS: two successful Ibex boots, including reset with retained RAM.
```

## FPGA build

The packaged build generated both the exported top-level bitstream and Vivado's
implementation bitstream. The routed timing report states that all specified
timing constraints were met:

| Metric | Result |
| --- | --- |
| Worst setup slack (WNS) | 1.410 ns |
| Total negative setup slack (TNS) | 0.000 ns |
| Worst hold slack (WHS) | 0.077 ns |
| Failing setup/hold endpoints | 0 / 0 |

Generated logs, tool projects, firmware images and bitstreams stay in the
external build directory. They are intentionally excluded from Git; rebuild
them with `make simulate` and `make bitstream`.

## Limits

- Physical board programming and on-board UART/LED behavior were not tested
  during this packaging verification.
- The bitstream is for the Arty A7-100T only.
- Timing is assessed against the supplied constraints. LED/UART outputs do
  not have external output-delay constraints; this is not full interface timing signoff.
- The tools report existing RAM/reset methodology warnings. The firmware
  linker also warns about a writable/executable LOAD segment, consistent with
  this RAM-based bring-up architecture.
- This is a functional smoke test, not exhaustive CPU or peripheral verification.
- Secure boot, ML-DSA integration, NTT integration and security measurements
  are outside the implemented setup.
