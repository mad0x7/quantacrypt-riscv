#!/usr/bin/env python3
"""Build a standalone RV32IMC image and a full 64 KiB, little-endian word MEM file."""
import argparse
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys

from build_paths import ROOT, target_root

RAM_BYTES = 64 * 1024


def find_toolchain():
    configured = os.environ.get("IBEX_TOOLCHAIN_BIN")
    search_path = None
    location = "PATH"
    if configured is not None:
        if not configured.strip():
            raise RuntimeError("IBEX_TOOLCHAIN_BIN is empty; unset it or provide the toolchain bin directory")
        directory = Path(configured).expanduser().resolve()
        if not directory.is_dir():
            raise RuntimeError(f"IBEX_TOOLCHAIN_BIN is not a directory: {directory}")
        search_path = str(directory)
        location = str(directory)
    for prefix in ("riscv32-unknown-elf-", "riscv64-unknown-elf-"):
        for driver in ("clang", "gcc"):
            compiler = shutil.which(prefix + driver, path=search_path)
            objcopy = shutil.which(prefix + "objcopy", path=search_path)
            if compiler and objcopy:
                return compiler, objcopy, driver == "clang"
    raise RuntimeError(
        f"No RISC-V compiler and matching objcopy found in {location}. "
        "Install riscv32-unknown-elf- or riscv64-unknown-elf- clang/gcc and objcopy, "
        "then set IBEX_TOOLCHAIN_BIN to their bin directory or add them to PATH."
    )


def build(simulation=False):
    out = target_root(simulation) / "firmware"
    compiler, objcopy, clang = find_toolchain()
    out.mkdir(parents=True, exist_ok=True)
    name = "program_sim" if simulation else "program"
    elf, binary, mem = (out / (name + suffix) for suffix in (".elf", ".bin", ".mem"))
    args = [str(compiler)]
    if clang:
        args += ["--target=riscv32-unknown-elf"]
    args += [
        "-march=rv32imc_zicsr", "-mabi=ilp32", "-mcmodel=medany", "-Os", "-g",
        "-Wall", "-Wextra", "-Werror", "-ffreestanding", "-fno-builtin",
        "-fno-stack-protector", "-msmall-data-limit=0", "-nostdlib",
        "-Wl,--no-relax", "-Wl,-T," + str(ROOT / "sw/link.ld"),
        "-Wl,-Map," + str(out / (name + ".map")),
    ]
    if simulation:
        args += ["-DBLINK_CYCLES=10000u"]
    args += [str(ROOT / "sw/start.S"), str(ROOT / "sw/main.c"), "-o", str(elf)]
    subprocess.run(args, check=True)
    subprocess.run([str(objcopy), "-O", "binary", str(elf), str(binary)], check=True)
    elf_data = elf.read_bytes()
    if len(elf_data) < 52 or elf_data[:6] != b"\x7fELF\x01\x01" or struct.unpack_from("<I", elf_data, 24)[0] != 0x80:
        raise RuntimeError("Expected ELF32 little-endian firmware with entry 0x80")
    payload = binary.read_bytes()
    if len(payload) > RAM_BYTES:
        raise RuntimeError("Firmware binary exceeds 64 KiB")
    payload += bytes(RAM_BYTES - len(payload))
    with mem.open("w") as stream:
        for offset in range(0, RAM_BYTES, 4):
            stream.write(f"{int.from_bytes(payload[offset:offset + 4], 'little'):08x}\n")
    print(f"Firmware built: {binary.stat().st_size} initialized bytes; entry 0x80", flush=True)
    print(f"RAM image: {mem}", flush=True)
    return mem


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--simulation", action="store_true")
    arguments = parser.parse_args()
    try:
        build(arguments.simulation)
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        print(f"Firmware build failed: {error}", file=sys.stderr)
        sys.exit(1)
