"""
NPU (Mobilint) status monitoring module.

This module provides functionality to parse and display NPU status
from mobilint-cli command output.
"""

import re
import subprocess
from dataclasses import dataclass, field
from typing import List, Optional, Dict, Any


@dataclass
class NPUProcess:
    """Represents a process running on an NPU core."""
    npu_index: int
    core_index: int  # Current core being used
    total_cores: int  # Total cores allocated
    pid: int
    process_name: str
    npu_memory: int  # in MB
    count: int
    utilization: float  # percentage


@dataclass
class NPUCore:
    """Represents a single NPU core status."""
    core_index: int
    processes: List[NPUProcess] = field(default_factory=list)

    @property
    def is_active(self) -> bool:
        """Return True if any process is running on this core."""
        return len(self.processes) > 0

    @property
    def utilization(self) -> float:
        """Return total utilization for this core."""
        return sum(p.utilization for p in self.processes)


@dataclass
class NPUInfo:
    """
    Represents a single NPU device's information.

    Contains all hardware stats and running processes for one NPU.
    """
    index: int
    name: str
    firmware_version: str
    signature: int
    temperature: int  # in Celsius
    firmware_crc: str
    power_npu: float  # in Watts
    power_total: float  # in Watts
    current_npu: float  # in Amps
    current_total: float  # in Amps
    clock_npu: int  # in MHz
    clock_bus: int  # in MHz
    memory_used: int  # in MB
    memory_total: int  # in MB
    utilization: float  # percentage
    cores: Dict[int, NPUCore] = field(default_factory=dict)

    @property
    def memory_free(self) -> int:
        """Returns the free memory (in MB)."""
        return max(self.memory_total - self.memory_used, 0)

    @property
    def processes(self) -> List[NPUProcess]:
        """Returns all processes across all cores."""
        all_processes = []
        for core in self.cores.values():
            all_processes.extend(core.processes)
        return all_processes

    def get_core(self, core_index: int) -> NPUCore:
        """Get or create a core by index."""
        if core_index not in self.cores:
            self.cores[core_index] = NPUCore(core_index=core_index)
        return self.cores[core_index]


@dataclass
class NPUDriverVersions:
    """NPU driver version information."""
    aries: Optional[str] = None
    aries2: Optional[str] = None
    regulus: Optional[str] = None


def parse_mobilint_output(output: str) -> tuple[List[NPUInfo], NPUDriverVersions]:
    """
    Parse the output of 'mobilint-cli status show' command.

    Args:
        output: Raw string output from mobilint-cli status show

    Returns:
        Tuple of (list of NPUInfo objects, driver versions)

    The function parses a table-formatted output like:
    +------------------------------------------------------------------------------------------+
    | Mobilint-NPU-Monitor           Drivers - Aries: N/A     Aries2: 1.9.0   Regulus: N/A     |
    +------------------------------------------------------------------------------------------+
    | NPU  Name    Firmware Version |   Pwr:NPU/Total |     Clock:NPU/Bus |       Memory-Usage |
    | Sig  Temp        Firmware CRC |   Cur:NPU/Total |                   |           NPU-Util |
    |===============================+=================+===================+====================|
    |   0  Aries2(aries0)       1.1 |   3.90W  12.72W | 1250MHz / 1000MHz |      0MB / 16384MB |
    |   0  37 C            fb9a5980 |   0.32A   1.04A |                   |              0.00% |
    +-------------------------------+-----------------+-------------------+--------------------+
    """
    npus: List[NPUInfo] = []
    drivers = NPUDriverVersions()
    lines = output.strip().split('\n')

    # Parse driver versions from header
    for line in lines:
        if 'Drivers' in line:
            aries_match = re.search(r'Aries:\s*(\S+)', line)
            aries2_match = re.search(r'Aries2:\s*(\S+)', line)
            regulus_match = re.search(r'Regulus:\s*(\S+)', line)

            if aries_match:
                val = aries_match.group(1)
                drivers.aries = None if val == 'N/A' else val
            if aries2_match:
                val = aries2_match.group(1)
                drivers.aries2 = None if val == 'N/A' else val
            if regulus_match:
                val = regulus_match.group(1)
                drivers.regulus = None if val == 'N/A' else val
            break

    # Find NPU data lines (pairs of lines for each NPU)
    # First line: index, name, firmware version, power, clock, memory
    # Second line: signature, temp, crc, current, utilization
    npu_data_pattern = re.compile(
        r'\|\s*(\d+)\s+'  # NPU index
        r'(\S+)\s+'  # Name (e.g., Aries2(aries0))
        r'(\S+)\s*\|'  # Firmware version
        r'\s*([\d.]+)W\s+([\d.]+)W\s*\|'  # Power NPU/Total
        r'\s*(\d+)MHz\s*/\s*(\d+)MHz\s*\|'  # Clock NPU/Bus
        r'\s*(\d+)MB\s*/\s*(\d+)MB\s*\|'  # Memory used/total
    )
    npu_data_line2_pattern = re.compile(
        r'\|\s*(\d+)\s+'  # Signature
        r'(\d+)\s*C\s+'  # Temperature
        r'(\S+)\s*\|'  # CRC
        r'\s*([\d.]+)A\s+([\d.]+)A\s*\|'  # Current NPU/Total
        r'\s*\|'  # Empty clock column
        r'\s*([\d.]+)%\s*\|'  # Utilization
    )

    i = 0
    while i < len(lines):
        line = lines[i]
        match1 = npu_data_pattern.search(line)
        if match1 and i + 1 < len(lines):
            line2 = lines[i + 1]
            match2 = npu_data_line2_pattern.search(line2)
            if match2:
                npu = NPUInfo(
                    index=int(match1.group(1)),
                    name=match1.group(2),
                    firmware_version=match1.group(3),
                    power_npu=float(match1.group(4)),
                    power_total=float(match1.group(5)),
                    clock_npu=int(match1.group(6)),
                    clock_bus=int(match1.group(7)),
                    memory_used=int(match1.group(8)),
                    memory_total=int(match1.group(9)),
                    signature=int(match2.group(1)),
                    temperature=int(match2.group(2)),
                    firmware_crc=match2.group(3),
                    current_npu=float(match2.group(4)),
                    current_total=float(match2.group(5)),
                    utilization=float(match2.group(6)),
                )
                npus.append(npu)
                i += 2
                continue
        i += 1

    # Parse processes section
    # | NPU  Core      PID   Process name                         NPU-MEM       Count  %NPU-Core |
    # Core can be "0/0" format (current_core/total_cores) or just a number
    process_pattern = re.compile(
        r'\|\s*(\d+)\s+'  # NPU index
        r'(\d+)/(\d+)\s+'  # Core (current/total format)
        r'(\d+)\s+'  # PID
        r'(.+?)\s+'  # Process name
        r'(\d+)MB\s+'  # NPU-MEM
        r'(\d+)\s+'  # Count
        r'([\d.]+)%\s*\|'  # %NPU-Core
    )

    for line in lines:
        proc_match = process_pattern.search(line)
        if proc_match:
            npu_idx = int(proc_match.group(1))
            process = NPUProcess(
                npu_index=npu_idx,
                core_index=int(proc_match.group(2)),
                total_cores=int(proc_match.group(3)),
                pid=int(proc_match.group(4)),
                process_name=proc_match.group(5).strip(),
                npu_memory=int(proc_match.group(6)),
                count=int(proc_match.group(7)),
                utilization=float(proc_match.group(8)),
            )
            # Find the NPU and add the process to the appropriate core
            for npu in npus:
                if npu.index == npu_idx:
                    core = npu.get_core(process.core_index)
                    core.processes.append(process)
                    break

    return npus, drivers


def query_npu_status() -> tuple[List[NPUInfo], NPUDriverVersions]:
    """
    Execute mobilint-cli status show and parse the output.

    Returns:
        Tuple of (list of NPUInfo objects, driver versions)

    Raises:
        RuntimeError: If mobilint-cli command fails or is not found
    """
    try:
        result = subprocess.run(
            ['mobilint-cli', 'status', 'show'],
            capture_output=True,
            text=True,
            timeout=10
        )
        if result.returncode != 0:
            raise RuntimeError(
                f"mobilint-cli failed with return code {result.returncode}: "
                f"{result.stderr}"
            )
        return parse_mobilint_output(result.stdout)
    except FileNotFoundError:
        raise RuntimeError(
            "mobilint-cli not found. Please ensure Mobilint SDK is installed."
        )
    except subprocess.TimeoutExpired:
        raise RuntimeError("mobilint-cli command timed out")


def is_npu_available() -> bool:
    """Check if NPU monitoring is available."""
    try:
        result = subprocess.run(
            ['mobilint-cli', 'status', 'show'],
            capture_output=True,
            text=True,
            timeout=5
        )
        return result.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def npu_count() -> int:
    """Return the number of available NPUs."""
    try:
        npus, _ = query_npu_status()
        return len(npus)
    except RuntimeError:
        return 0
