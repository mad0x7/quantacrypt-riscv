#!/usr/bin/env python3
"""Build the pinned Ibex bring-up design with FuseSoC."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

from build_firmware import build
from build_paths import ROOT, target_root


def find_ibex():
    configured = os.environ.get("IBEX_ROOT")
    if configured is not None and not configured.strip():
        raise RuntimeError("IBEX_ROOT is empty; unset it or provide the Ibex checkout directory")
    ibex = Path(configured).expanduser().resolve() if configured else ROOT / "third_party/ibex"
    if not (ibex / "ibex_top.core").is_file():
        raise RuntimeError(
            f"Ibex sources not found at {ibex}. Run the dependency setup script "
            "or set IBEX_ROOT to an existing checkout."
        )
    try:
        expected = json.loads((ROOT / "dependencies.json").read_text())["ibex"]["revision"]
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise RuntimeError(f"Cannot read the Ibex revision from dependencies.json: {error}") from error
    result = subprocess.run(
        ["git", "-C", str(ibex), "rev-parse", "HEAD"],
        capture_output=True, text=True,
    )
    if result.returncode:
        raise RuntimeError(f"Cannot read the Git revision of the Ibex checkout at {ibex}")
    actual = result.stdout.strip()
    if actual != expected:
        raise RuntimeError(
            f"Ibex revision mismatch at {ibex}: expected {expected}, found {actual}. "
            "Use a checkout at the pinned revision or run dependency setup in a fresh location. "
            "The existing checkout has not been changed."
        )
    return ibex


def find_fusesoc():
    requested = os.environ.get("FUSESOC", "fusesoc")
    found = shutil.which(os.path.expanduser(requested))
    if not found:
        raise RuntimeError(
            f"FuseSoC executable not found: {requested!r}. Activate the Python environment "
            "with FuseSoC installed, or set FUSESOC to its executable path."
        )
    return Path(found).absolute()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("target", choices=["sim", "synth"])
    arguments = parser.parse_args()
    directory = target_root(arguments.target == "sim")
    ibex = find_ibex()
    fusesoc = find_fusesoc()
    memory_image = build(simulation=arguments.target == "sim")
    output = directory / "fusesoc"
    output.mkdir(parents=True, exist_ok=True)
    log = directory / (arguments.target + ".log")
    env = os.environ.copy()
    env["PATH"] = str(fusesoc.parent) + os.pathsep + env.get("PATH", "")
    command = [
        str(fusesoc), "--cores-root=" + str(ibex), "--cores-root=" + str(ROOT),
        "run", "--build-root=" + str(output), "--target=" + arguments.target,
        "--setup", "--build",
    ]
    if arguments.target == "sim":
        command += ["--run"]
    command += ["local:secureboot:minimal_soc:0.1", "--MEM_FILE=" + str(memory_image)]
    print(f"Building {arguments.target}; full output: {log}", flush=True)
    with log.open("w") as stream:
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT)
    lines = log.read_text(errors="replace").splitlines()
    if result.returncode:
        print("\n".join(lines[-100:]), file=sys.stderr)
        raise RuntimeError(f"Build failed; inspect {log}")
    if arguments.target == "sim":
        print("\n".join(lines[-20:]))
    else:
        bitstreams = sorted(output.rglob("*.bit"))
        if not bitstreams:
            raise RuntimeError("Vivado finished but no bitstream was found")
        print("Bitstream generated:")
        for bitstream in bitstreams:
            print(bitstream)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        print(f"Build failed: {error}", file=sys.stderr)
        sys.exit(1)
