#!/usr/bin/env python3
"""Fetch exactly the reviewed Ibex revision without changing an existing checkout."""

import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def git(directory, *arguments, check=True):
    return subprocess.run(
        ["git", "-C", str(directory), *arguments],
        check=check, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )


def main():
    dependency = json.loads((ROOT / "dependencies.json").read_text())["ibex"]
    destination = ROOT / "third_party" / "ibex"
    revision = dependency["revision"]
    url = dependency["url"]
    if destination.exists():
        top = git(destination, "rev-parse", "--show-toplevel", check=False)
        if top.returncode or Path(top.stdout.strip()).resolve() != destination.resolve():
            raise RuntimeError(f"{destination} exists but is not an Ibex Git checkout")
        if git(destination, "remote", "get-url", "origin").stdout.strip() != url:
            raise RuntimeError(f"Unexpected origin in {destination}; inspect it before proceeding")
        head = git(destination, "rev-parse", "--verify", "HEAD", check=False)
        if head.returncode == 0:
            if head.stdout.strip() != revision:
                raise RuntimeError(
                    f"{destination} is at a different revision; preserve your work and "
                    "move that checkout aside before fetching the pinned dependency"
                )
            if git(destination, "status", "--porcelain", "--untracked-files=no").stdout.strip():
                raise RuntimeError(f"Tracked Ibex files have local changes in {destination}")
            print(f"Ibex already available at {revision}\n{destination}")
            return
        if git(destination, "status", "--porcelain").stdout.strip():
            raise RuntimeError(f"Uncommitted files in incomplete checkout {destination}")
    else:
        destination.mkdir(parents=True)
        git(destination, "init")
        git(destination, "remote", "add", "origin", url)

    print(f"Fetching Ibex {revision} from {url}", flush=True)
    git(destination, "fetch", "--depth", "1", "origin", revision)
    git(destination, "checkout", "--detach", revision)
    if not (destination / "ibex_top.core").is_file():
        raise RuntimeError("The fetched checkout does not contain ibex_top.core")
    print(f"Ibex ready: {destination}")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        print(error.stderr.strip() or str(error), file=sys.stderr)
        sys.exit(1)
    except (OSError, RuntimeError, ValueError, KeyError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
