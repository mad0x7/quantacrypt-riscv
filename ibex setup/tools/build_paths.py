"""Keep generated tool paths independent of the source folder's name."""
import hashlib
import os
from pathlib import Path
import re
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def build_root():
    """Return a stable per-checkout output directory safe for generated Tcl/Make."""
    checkout_id = hashlib.sha256(str(ROOT).encode()).hexdigest()[:12]
    default = Path(tempfile.gettempdir()) / f"quantacrypt-ibex-{os.getuid()}" / checkout_id
    configured = os.environ.get("BUILD_ROOT")
    if configured is not None and not configured.strip():
        raise RuntimeError("BUILD_ROOT is empty; unset it or provide an output directory")
    output = Path(configured).expanduser().resolve() if configured is not None else default.resolve()
    if not re.fullmatch(r"[A-Za-z0-9_./-]+", str(output)):
        raise RuntimeError(
            f"BUILD_ROOT resolves to an unsupported path: {output!s}. "
            "Use only letters, digits, '/', '.', '_' and '-' in the output path "
            "(for example /tmp/quantacrypt-ibex-build). The source folder may contain spaces."
        )
    return output


def target_root(simulation=False):
    return build_root() / ("sim" if simulation else "synth")
