"""
NPU (Mobilint) status monitoring module.

Queries Mobilint NPUs through the official ``mbltml`` bindings, the Mobilint
counterpart of NVIDIA's NVML. This is the same library `mblt-tracker` and
`mblt-status` are built on, so npustat reads the very same counters the vendor
tools do -- no CLI output scraping is involved.
"""

import os
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

import psutil

from npustat.npuml import ensure_initialized, mbltml

# Human-readable names for mbltmlDeviceType_t (device family).
DEVICE_TYPE_NAMES = {
    0x1: 'Aries',
    0x2: 'Regulus',
    0x4: 'Regulus(USB)',
}

# Human-readable names for mbltmlHardwareVersion_t (actual chip revision).
HARDWARE_VERSION_NAMES = {
    0x1: 'Aries',
    0x2: 'Regulus',
    0x3: 'Aries2',
    0x4: 'Regulus2',
}

# Human-readable names for mbltmlExtraPmicId_t (selectable power rail).
EXTRA_RAIL_NAMES = {
    0: 'NPU',
    1: 'DDR',
    2: 'PMIC',
    3: 'Goldfinger',
}

SIGNAL_TYPE_NAMES = {
    0: 'Interrupt',
    1: 'Polling',
}

# mbltmlCore_t sentinel for the aggregated (global) core of a cluster.
CORE_GLOBAL = 0x0000FFFE

_MB = 1024 * 1024


@dataclass
class NPUProcess:
    """Represents a process running on an NPU."""
    npu_index: int
    pid: int
    process_name: str
    npu_memory: int  # in MB
    count: int  # number of NPU samples attributed to the process
    utilization: float  # percentage
    username: Optional[str] = None
    full_command: Optional[List[str]] = None


@dataclass
class NPUCore:
    """Represents a single NPU core's usage over the last sampling window."""
    cluster: int  # cluster index (0, 1, ...)
    core: int  # core index within the cluster, or -1 for the global core
    npu_time_us: int  # accumulated NPU active time, microseconds
    interval_us: int  # sampling window covered by npu_time_us, microseconds

    @property
    def is_global(self) -> bool:
        """Whether this record aggregates the whole cluster."""
        return self.core < 0

    @property
    def utilization(self) -> float:
        """Utilization of this core over the sampling window, in percent."""
        if self.interval_us <= 0:
            return 0.0
        return 100.0 * self.npu_time_us / self.interval_us

    @property
    def is_active(self) -> bool:
        """Whether the core did any work during the sampling window."""
        return self.npu_time_us > 0

    @property
    def label(self) -> str:
        """Short display label, e.g. ``C0/G`` or ``C0/c2``."""
        return f"C{self.cluster}/{'G' if self.is_global else f'c{self.core}'}"


@dataclass
class NPUInfo:
    """Represents a single NPU device's information."""
    index: int
    node_name: str  # e.g. /dev/aries0
    device_type: int  # mbltmlDeviceType_t
    hardware_version: int  # mbltmlHardwareVersion_t
    firmware_version: str
    firmware_revision: int
    firmware_crc: int
    temperature: int  # in Celsius
    signal_type: int
    clock_npu: int  # in MHz
    clock_bus: int  # in MHz
    fan_duty: Optional[int]  # in percent
    power_total: float  # in Watts
    current_total: float  # in Amps
    voltage_total: float  # in Volts
    extra_rail: Optional[int]  # mbltmlExtraPmicId_t of the selected rail
    extra_rail_power: Optional[float]  # in Watts
    extra_rail_current: Optional[float]  # in Amps
    extra_rail_voltage: Optional[float]  # in Volts
    memory_used: int  # in MB
    memory_total: int  # in MB
    utilization: float  # percentage
    pcie: Dict[str, int] = field(default_factory=dict)
    cores: List[NPUCore] = field(default_factory=list)
    processes: List[NPUProcess] = field(default_factory=list)

    @property
    def device_name(self) -> str:
        """Device family name, e.g. ``Aries``."""
        return DEVICE_TYPE_NAMES.get(self.device_type, 'NPU')

    @property
    def chip_name(self) -> str:
        """Actual chip revision name, e.g. ``Aries2``."""
        return HARDWARE_VERSION_NAMES.get(self.hardware_version, 'Unknown')

    @property
    def name(self) -> str:
        """Display name, e.g. ``Aries(aries0)``."""
        return f"{self.device_name}({os.path.basename(self.node_name)})"

    @property
    def firmware_version_str(self) -> str:
        """Firmware version including its revision, e.g. ``1.1 (Rev: 0)``."""
        return f"{self.firmware_version} (Rev: {self.firmware_revision})"

    @property
    def firmware_crc_str(self) -> str:
        return f"0x{self.firmware_crc:08X}"

    @property
    def signal_type_str(self) -> str:
        return SIGNAL_TYPE_NAMES.get(self.signal_type, str(self.signal_type))

    @property
    def extra_rail_name(self) -> Optional[str]:
        if self.extra_rail is None:
            return None
        return EXTRA_RAIL_NAMES.get(self.extra_rail, str(self.extra_rail))

    @property
    def power_npu(self) -> Optional[float]:
        """Power of the NPU rail, if that rail is the one currently selected.

        Only one extra rail is sampled by the firmware at a time; switching
        rails takes up to a second to take effect, so npustat reports the rail
        that happens to be selected rather than forcing a switch.
        """
        if self.extra_rail == 0:
            return self.extra_rail_power
        return None

    @property
    def memory_free(self) -> int:
        """Returns the free memory (in MB)."""
        return max(self.memory_total - self.memory_used, 0)

    @property
    def clusters(self) -> Dict[int, List[NPUCore]]:
        """Cores grouped by cluster index, each sorted global-first."""
        grouped: Dict[int, List[NPUCore]] = {}
        for core in self.cores:
            grouped.setdefault(core.cluster, []).append(core)
        for cores in grouped.values():
            cores.sort(key=lambda c: (not c.is_global, c.core))
        return grouped


@dataclass
class NPUDriverVersions:
    """NPU driver version information, keyed by device family."""
    aries: Optional[str] = None
    regulus: Optional[str] = None
    regulus_usb: Optional[str] = None


def _safe(fn, *args, default=None):
    """Call an mbltml getter, returning ``default`` when it is unsupported."""
    try:
        return fn(*args)
    except Exception:
        return default


def _cluster_index(raw_cluster: int) -> int:
    """Convert mbltmlCluster_t (0x00010000 << n) into a 0-based index."""
    if raw_cluster <= 0:
        return -1
    return (raw_cluster >> 16).bit_length() - 1


def _core_index(raw_core: int) -> int:
    """Convert mbltmlCore_t (1-based, 0xFFFE == global) into a 0-based index."""
    if raw_core == CORE_GLOBAL:
        return -1
    return raw_core - 1


# psutil.Process objects are cached across queries: constructing one is the
# expensive part, and watch mode re-queries every refresh interval. The cache
# is bounded so a long-running watch on a busy host cannot grow without limit.
_PROCESS_CACHE_LIMIT = 256
_process_cache: Dict[int, psutil.Process] = {}


def _lookup_process(pid: int) -> Dict[str, Any]:
    """Resolve a PID into a name/username/cmdline, tolerating dead processes."""
    info: Dict[str, Any] = {
        'process_name': '?', 'username': None, 'full_command': None,
    }
    try:
        proc = _process_cache.get(pid)
        if proc is None:
            if len(_process_cache) >= _PROCESS_CACHE_LIMIT:
                _process_cache.clear()
            proc = psutil.Process(pid=pid)
            _process_cache[pid] = proc

        cmdline = _safe(proc.cmdline, default=[]) or []
        if cmdline:
            info['process_name'] = os.path.basename(cmdline[0])
            info['full_command'] = cmdline
        else:
            # Zombie or kernel thread: cmdline is empty but the name survives.
            info['process_name'] = _safe(proc.name, default='?') or '?'
        info['username'] = _safe(proc.username)
    except (psutil.NoSuchProcess, psutil.AccessDenied, ValueError):
        _process_cache.pop(pid, None)
    return info


def _query_driver_versions() -> NPUDriverVersions:
    drivers = NPUDriverVersions()
    for attr, device_type in (
        ('aries', mbltml.MBLTML_DEVICE_ARIES),
        ('regulus', mbltml.MBLTML_DEVICE_REGULUS),
        ('regulus_usb', mbltml.MBLTML_DEVICE_REGULUS_USB),
    ):
        version = _safe(mbltml.mbltmlGetDriverVersion, device_type)
        if version:
            revision = _safe(mbltml.mbltmlGetDriverRevision, device_type)
            if revision is not None:
                version = f"{version}(Rev:{revision})"
            setattr(drivers, attr, version)
    return drivers


def _query_cores(dev_no: int) -> List[NPUCore]:
    cores = []
    for info in _safe(mbltml.mbltmlGetCoreInfos, dev_no, default=[]) or []:
        cluster = _cluster_index(info.core_id.cluster)
        if cluster < 0:
            continue  # MBLTML_CLUSTER_ERROR
        cores.append(NPUCore(
            cluster=cluster,
            core=_core_index(info.core_id.core),
            npu_time_us=info.npu_time,
            interval_us=info.interval,
        ))
    return cores


def _query_processes(dev_no: int) -> List[NPUProcess]:
    processes = []
    for info in _safe(mbltml.mbltmlGetProcessInfos, dev_no, default=[]) or []:
        # The binding over-allocates its output array; skip the empty slots.
        if info.pid <= 0:
            continue
        utilization = 0.0
        if info.total_interval_us > 0:
            utilization = 100.0 * info.total_npu_time_us / info.total_interval_us
        processes.append(NPUProcess(
            npu_index=dev_no,
            pid=info.pid,
            npu_memory=info.npu_memory_usage // _MB,
            count=info.counts,
            utilization=utilization,
            **_lookup_process(info.pid),
        ))
    return processes


def _query_device(dev_no: int) -> NPUInfo:
    memory_used = _safe(mbltml.mbltmlGetMemoryUsage, dev_no, default=0) or 0
    memory_total = _safe(mbltml.mbltmlGetMemoryTotal, dev_no, default=0) or 0

    pcie = {}
    for key, fn in (
        ('vendor_id', mbltml.mbltmlGetVendorId),
        ('device_id', mbltml.mbltmlGetDeviceId),
        ('sub_vendor_id', mbltml.mbltmlGetSubVendorId),
        ('sub_device_id', mbltml.mbltmlGetSubDeviceId),
        ('generation', mbltml.mbltmlGetPcieGen),
        ('lanes', mbltml.mbltmlGetPcieLanes),
        ('revision', mbltml.mbltmlGetPcieRev),
        ('class_code', mbltml.mbltmlGetPcieClassCode),
    ):
        value = _safe(fn, dev_no)
        if value is not None:
            pcie[key] = value

    return NPUInfo(
        index=dev_no,
        node_name=_safe(mbltml.mbltmlGetNodeName, dev_no, default='') or '',
        device_type=_safe(mbltml.mbltmlGetDeviceType, dev_no, default=0) or 0,
        hardware_version=_safe(
            mbltml.mbltmlGetHardwareVersion, dev_no, default=0) or 0,
        firmware_version=_safe(
            mbltml.mbltmlGetFirmwareVersion, dev_no, default='?') or '?',
        firmware_revision=_safe(
            mbltml.mbltmlGetFirmwareRevision, dev_no, default=0) or 0,
        firmware_crc=_safe(mbltml.mbltmlGetFirmwareCRC, dev_no, default=0) or 0,
        temperature=_safe(mbltml.mbltmlGetTemperature, dev_no, default=0) or 0,
        signal_type=_safe(mbltml.mbltmlGetSignalType, dev_no, default=0) or 0,
        clock_npu=_safe(mbltml.mbltmlGetNPUClock, dev_no, default=0) or 0,
        clock_bus=_safe(mbltml.mbltmlGetBusClock, dev_no, default=0) or 0,
        fan_duty=_safe(mbltml.mbltmlGetFanDuty, dev_no),
        power_total=_safe(mbltml.mbltmlGetTotalPower, dev_no, default=0.0) or 0.0,
        current_total=_safe(
            mbltml.mbltmlGetTotalCurrent, dev_no, default=0.0) or 0.0,
        voltage_total=_safe(
            mbltml.mbltmlGetTotalVoltage, dev_no, default=0.0) or 0.0,
        extra_rail=_safe(mbltml.mbltmlGetExtraPmicId, dev_no),
        extra_rail_power=_safe(mbltml.mbltmlGetExtraPmicPower, dev_no),
        extra_rail_current=_safe(mbltml.mbltmlGetExtraPmicCurrent, dev_no),
        extra_rail_voltage=_safe(mbltml.mbltmlGetExtraPmicVoltage, dev_no),
        memory_used=memory_used // _MB,
        memory_total=memory_total // _MB,
        utilization=_safe(
            mbltml.mbltmlGetTotalUtilization, dev_no, default=0.0) or 0.0,
        pcie=pcie,
        cores=_query_cores(dev_no),
        processes=_query_processes(dev_no),
    )


def query_npu_status() -> "tuple[List[NPUInfo], NPUDriverVersions]":
    """
    Query every Mobilint NPU on the local machine through mbltml.

    Returns:
        Tuple of (list of NPUInfo objects, driver versions)

    Raises:
        RuntimeError: If mbltml is unavailable or the query fails.
    """
    try:
        ensure_initialized()
        count = mbltml.mbltmlGetDeviceCount()
        npus = [_query_device(dev_no) for dev_no in range(count)]
        return npus, _query_driver_versions()
    except RuntimeError:
        raise
    except Exception as e:
        raise RuntimeError(f"Failed to query Mobilint NPUs: {e}") from e


def is_npu_available() -> bool:
    """Check if NPU monitoring is available."""
    try:
        ensure_initialized()
        return mbltml.mbltmlGetDeviceCount() > 0
    except Exception:
        return False


def npu_count() -> int:
    """Return the number of available NPUs."""
    try:
        ensure_initialized()
        return mbltml.mbltmlGetDeviceCount()
    except Exception:
        return 0
