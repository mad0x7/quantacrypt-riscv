# Hardware interface

## Configuration

- Board: Digilent Arty A7-100T, device `xc7a100tcsg324-1`.
- Clock: 100 MHz oscillator; MMCM generates a 50 MHz SoC clock.
- Reset: active-low board reset, held until the MMCM locks; release is synchronized.
- CPU: Ibex, RV32IMC with machine CSRs, FPGA register file, no instruction cache.
- Memory: 64 KiB initialized block RAM with staged requests and two-cycle responses.
- Firmware entry: byte address `0x00000080` (`boot_addr_i + 0x80`).
- Stack top: `0x00010000`; the linker reserves the top 4 KiB for the stack.

## Memory map

| Address | Access | Function |
| --- | --- | --- |
| `0x00000000–0x0000FFFF` | Read/write/execute | RAM, including vectors, program and data |
| `0x80000000` | Read/write | GPIO output; low four bits drive LEDs |
| `0x80001000` | Write | UART transmit byte; low byte of the write data |
| `0x80001004` | Read | UART status; bit 0 is busy |

Software polls the busy bit before UART writes. Hardware also stalls a
transmit-byte write request before acceptance while the transmitter is busy. Addresses outside
the decoded RAM and peripheral regions receive error responses.

The runtime sets the stack and global pointers, initializes machine trap
handling, enables the cycle counter, and clears BSS on every reset. RAM is
retained across reset, so the simulation explicitly checks that BSS is cleared
again on the second boot.

## Board pins

| Signal | FPGA package pin | Use |
| --- | --- | --- |
| `CLK100MHZ` | E3 | 100 MHz oscillator |
| `ck_rst` | C2 | Active-low reset |
| `led[0]` | H5 | LED 0 |
| `led[1]` | J5 | LED 1 |
| `led[2]` | T9 | LED 2 |
| `led[3]` | T10 | LED 3 |
| `uart_tx` | D10 | FPGA UART TX to USB serial bridge |

All signals use LVCMOS33. UART runs at approximately 115200 baud, 8N1.

## Integration boundary

The ML-DSA package elsewhere in this repository targets an Ibex Simple System
environment. This local SoC has its own linker layout and UART/GPIO register
map; its existing ML-DSA ELF is not a drop-in firmware image here.

The NTT accelerator is also not connected to this SoC yet. Integrating it
requires address decoding, a bus adapter, firmware register access, and
integration tests.

RAM is writable and executable, and `SecureIbex` is disabled. There is no
trusted boot ROM, signature verification, execution protection, entropy source,
or debug-security policy in this bring-up design.
