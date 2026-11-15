# QuantaCrypt RISC-V

RISC-V and FPGA components for the QuantaCrypt project.

| Component | Purpose |
| --- | --- |
| [Ibex setup](ibex%20setup/README.md) | Arty A7-100T bring-up: Ibex CPU, RAM, UART, LEDs, firmware and FPGA build; contributed by [shaunakg08s](https://github.com/shaunakg08s) |
| [ML-DSA-44 software](mldsa44_ibex/README.md) | Portable ML-DSA-44 software baseline and Ibex-targeted application |
| [NTT accelerator](ntt_accelerator/README.md) | Forward/inverse NTT hardware, MMIO wrapper and verification |

Each component has its own setup instructions and verification notes. The
Ibex bring-up package does not yet connect the NTT accelerator or run the
ML-DSA application; those integration steps remain separate project work.
