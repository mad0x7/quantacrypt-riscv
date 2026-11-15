# Upstream dependencies

[Ibex](https://github.com/lowRISC/ibex) is the RISC-V CPU developed by lowRISC
and its contributors. This setup uses commit
[`af456e25575013668ab56725268126f6b0feca35`](https://github.com/lowRISC/ibex/tree/af456e25575013668ab56725268126f6b0feca35),
recorded in [`dependencies.json`](../dependencies.json).

Run `make dependencies` from the setup directory to fetch that exact revision
into `third_party/ibex/`. The downloaded checkout is ignored by this repository;
the fetch script and revision record are committed instead. The fetch script
does not update or overwrite an existing checkout at a different revision.

Ibex is licensed under Apache-2.0. Its `LICENSE`, `NOTICE`, `CREDITS.md`, and
the individual notices in its vendored dependencies remain in the downloaded
checkout. This package does not claim authorship of upstream Ibex code.

`ibex-demo-system` is not a dependency: the local `rtl/ibex_minimal_soc.sv`
provides this setup's RAM and peripherals directly around `ibex_top`.
