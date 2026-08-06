"""Imports mbltml (Mobilint NPU monitoring library) with sanity checks.

This is the NPU counterpart of :mod:`npustat.nvml`. Unlike pynvml, whose
absence is fatal, mbltml is optional: npustat must keep working on hosts that
have NVIDIA GPUs but no Mobilint NPU. Import errors and initialization errors
are therefore recorded and re-raised only when NPU data is actually requested.
"""

import atexit
import textwrap

_import_error = None

try:
    import mbltml  # type: ignore

    if not hasattr(mbltml, 'mbltmlGetDeviceCount'):
        raise ImportError(
            "The installed `mbltml` module does not expose the expected API. "
            "Please install Mobilint's official monitoring bindings "
            "(`pip install mbltml`).")

except ImportError as e:  # pragma: no cover - depends on the host
    mbltml = None  # type: ignore
    _import_error = ImportError(textwrap.dedent(
        """\
        mbltml is missing or not usable.

        npustat queries Mobilint NPUs through the official `mbltml` bindings.

        (Suggested Fix)

        $ pip install mbltml

        The root cause: """ + str(e)))


# Upon first use, let mbltml be initialized and remain active throughout the
# lifespan of the python process (mirrors how npustat.nvml handles pynvml).
_initialized = False
_init_error = None


def _shutdown():  # pragma: no cover - process teardown
    if mbltml is None:
        return
    try:
        mbltml.mbltmlShutdown()
    except Exception:
        pass


def ensure_initialized():
    """Initialize mbltml once, raising the recorded error if unavailable."""
    global _initialized, _init_error

    if _initialized:
        return
    if _init_error is not None:
        raise _init_error
    if mbltml is None:
        assert _import_error is not None
        raise _import_error

    try:
        mbltml.mbltmlInit()
    except Exception as exc:
        # No driver, no device, or an unloadable libmbltml.so.
        _init_error = exc
        raise

    _initialized = True
    atexit.register(_shutdown)


def is_initialized() -> bool:
    """Whether mbltml has been successfully initialized."""
    return _initialized


__all__ = [
    'mbltml',
    'ensure_initialized',
    'is_initialized',
]
