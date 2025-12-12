"""
The npustat module - GPU and NPU monitoring tool.
"""

# isort: skip_file
try:
    from ._version import version as __version__
    from ._version import version_tuple as __version_tuple__
except (ImportError, AttributeError) as ex:
    raise ImportError(
        "Unable to find `npustat.__version__` string. "
        "Please try reinstalling npustat; or if you are on a development "
        "version, then run `pip install -e .` and try again."
    ) from ex

from .core import GPUStat, GPUStatCollection
from .core import new_query, gpu_count, is_available
from .core_npu import NPUStat, NPUStatCollection, new_npu_query
from .npu import is_npu_available, npu_count
from .cli import print_gpustat, main


__all__ = (
    '__version__',
    'GPUStat',
    'GPUStatCollection',
    'new_query',
    'gpu_count',
    'is_available',
    'NPUStat',
    'NPUStatCollection',
    'new_npu_query',
    'is_npu_available',
    'npu_count',
    'print_gpustat',
    'main',
)
