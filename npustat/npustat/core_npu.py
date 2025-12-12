"""
Implementation of NPU statistics display.

This module provides NPUStat and NPUStatCollection classes
for displaying Mobilint NPU status in a format similar to gpustat.
"""

import json
import locale
import os
import platform
import sys
from datetime import datetime
from io import StringIO
from typing import Any, Dict, List, Optional, Sequence

from blessed import Terminal

from npustat import util
from npustat.npu import (
    NPUInfo, NPUProcess, NPUCore, NPUDriverVersions,
    query_npu_status, is_npu_available, npu_count
)

NOT_SUPPORTED = 'Not Supported'
DEFAULT_NPUNAME_WIDTH = 20
IS_WINDOWS = 'windows' in platform.platform().lower()


class NPUStat:
    """
    Represents a single NPU's statistics.

    Wraps NPUInfo and provides formatted output methods.
    """

    def __init__(self, entry: NPUInfo):
        if not isinstance(entry, NPUInfo):
            raise TypeError(
                f'entry should be NPUInfo, {type(entry)} given'
            )
        self.entry = entry

    def __repr__(self) -> str:
        return self.print_to(StringIO()).getvalue()

    @property
    def index(self) -> int:
        """Returns the index of NPU."""
        return self.entry.index

    @property
    def name(self) -> str:
        """Returns the name of NPU (e.g., Aries2(aries0))."""
        return self.entry.name

    @property
    def firmware_version(self) -> str:
        """Returns the firmware version."""
        return self.entry.firmware_version

    @property
    def temperature(self) -> int:
        """Returns the temperature in Celsius."""
        return self.entry.temperature

    @property
    def memory_total(self) -> int:
        """Returns the total memory in MB."""
        return self.entry.memory_total

    @property
    def memory_used(self) -> int:
        """Returns the used memory in MB."""
        return self.entry.memory_used

    @property
    def memory_free(self) -> int:
        """Returns the free memory in MB."""
        return self.entry.memory_free

    @property
    def utilization(self) -> float:
        """Returns the NPU utilization percentage."""
        return self.entry.utilization

    @property
    def power_npu(self) -> float:
        """Returns the NPU power consumption in Watts."""
        return self.entry.power_npu

    @property
    def power_total(self) -> float:
        """Returns the total power consumption in Watts."""
        return self.entry.power_total

    @property
    def clock_npu(self) -> int:
        """Returns the NPU clock in MHz."""
        return self.entry.clock_npu

    @property
    def clock_bus(self) -> int:
        """Returns the bus clock in MHz."""
        return self.entry.clock_bus

    @property
    def processes(self) -> List[NPUProcess]:
        """Returns the list of processes running on the NPU."""
        return self.entry.processes

    @property
    def cores(self) -> Dict[int, NPUCore]:
        """Returns the cores dictionary."""
        return self.entry.cores

    def print_to(self, fp, *,
                 with_colors=True,
                 show_cmd=False,
                 show_full_cmd=False,
                 no_processes=False,
                 show_user=False,
                 show_pid=False,
                 show_power=None,
                 show_clock=False,
                 show_core_status=True,
                 npuname_width=None,
                 eol_char=os.linesep,
                 term=None,
                 ):
        """
        Print NPU status to the given file pointer.

        Args:
            fp: File pointer to write to
            with_colors: Enable colored output
            show_cmd: Show command name of running processes
            show_full_cmd: Show full command line
            no_processes: Hide process information
            show_user: Show username (not available for NPU)
            show_pid: Show PID of running processes
            show_power: Show power consumption
            show_clock: Show clock frequencies
            show_core_status: Show per-core status
            npuname_width: Width for NPU name column
            eol_char: End of line character
            term: Terminal instance for color output
        """
        if term is None:
            term = Terminal(stream=sys.stdout)

        # Color settings
        colors = {}

        def _conditional(cond_fn, true_value, false_value,
                         error_value=term.bold_black):
            try:
                return cond_fn() and true_value or false_value
            except Exception:
                return error_value

        colors['C0'] = term.normal
        colors['C1'] = term.cyan
        colors['CName'] = term.blue
        colors['CTemp'] = _conditional(lambda: self.temperature < 50, term.red, term.bold_red)
        colors['CMemU'] = term.bold_yellow
        colors['CMemT'] = term.yellow
        colors['CMemP'] = term.yellow
        colors['CUser'] = term.bold_black
        colors['CUtil'] = _conditional(lambda: self.utilization < 30, term.green, term.bold_green)
        colors['CPowU'] = _conditional(
            lambda: self.power_npu / self.power_total < 0.4 if self.power_total > 0 else True,
            term.magenta, term.bold_magenta
        )
        colors['CPowL'] = term.magenta
        colors['CClock'] = term.cyan
        colors['CCore'] = term.bold_cyan
        colors['CCoreActive'] = term.bold_green
        colors['CCoreIdle'] = term.bold_black
        colors['CCmd'] = term.color(24)
        colors['CNPU'] = term.bold_magenta  # NPU 구분용 색상

        if not with_colors:
            for k in list(colors.keys()):
                colors[k] = ''

        def _repr(v, none_value='??'):
            return none_value if v is None else v

        reps = []

        def _write(*args, color=None, end=''):
            args = [str(x) for x in args]
            if color:
                if color in colors:
                    color = colors[color]
                args = [color] + args + [term.normal]
            if end:
                args.append(end)
            reps.extend(args)

        def rjustify(x, size):
            return f"{x:>{size}}"

        # NPU index with NPU label
        _write(f"[N{self.index}]", color='CNPU')
        _write(" ")

        # NPU name
        if npuname_width is None or npuname_width != 0:
            npuname_width = npuname_width or DEFAULT_NPUNAME_WIDTH
            _write(f"{util.shorten_left(self.name, width=npuname_width, placeholder='…'):{npuname_width}}",
                   color='CName')
            _write(" |")

        # Temperature
        _write(rjustify(self.temperature, 3), "°C", color='CTemp', end=', ')

        # Utilization (integer to match GPU format)
        _write(rjustify(int(self.utilization), 3), " %", color='CUtil')

        # Power
        if show_power:
            _write(",  ")
            _write(rjustify(f"{self.power_npu:.1f}", 5), color='CPowU')
            if show_power is True or 'limit' in str(show_power):
                _write(" / ")
                _write(rjustify(f"{self.power_total:.1f}", 5), ' W', color='CPowL')

        # Clock
        if show_clock:
            _write(",  ")
            _write(rjustify(self.clock_npu, 4), color='CClock')
            _write(" / ")
            _write(rjustify(self.clock_bus, 4), ' MHz', color='CClock')

        # Memory
        _write(" | ")
        _write(rjustify(self.memory_used, 5), color='CMemU')
        _write(" / ")
        _write(rjustify(self.memory_total, 5), color='CMemT')
        _write(" MB")

        # Add " |" only if processes information is to be added
        if not no_processes:
            _write(" |")

        # Show processes
        if not no_processes:
            processes = self.processes
            if processes:
                for p in processes:
                    _write(' ')
                    if show_pid:
                        _write(f"{p.pid}/", color='CUser')
                    if show_cmd:
                        _write(f"{p.process_name}", color='C1')
                    else:
                        _write(f"{p.process_name}", color='CUser')
                    _write('(', color='C0')
                    _write(f"{p.npu_memory}M", color='CMemP')
                    _write(')', color='C0')

        # Show per-core status summary
        if show_core_status and self.cores:
            _write(eol_char)
            for core_idx in sorted(self.cores.keys()):
                core = self.cores[core_idx]
                status_color = 'CCoreActive' if core.is_active else 'CCoreIdle'
                status_text = f"{core.utilization:.1f}%" if core.is_active else "idle"

                _write(f"    └─ Core {core_idx}/{core.processes[0].total_cores if core.processes else 0}: ", color='CCore')
                _write(status_text, color=status_color)

                if core.is_active:
                    for proc in core.processes:
                        _write(f" [{proc.process_name}:{proc.pid}]", color='CCmd')
                _write(eol_char)

        fp.write(''.join(reps))
        return fp

    def jsonify(self) -> Dict[str, Any]:
        """Convert to JSON-serializable dictionary."""
        return {
            'index': self.index,
            'name': self.name,
            'firmware_version': self.firmware_version,
            'temperature': self.temperature,
            'memory.used': self.memory_used,
            'memory.total': self.memory_total,
            'utilization': self.utilization,
            'power.npu': self.power_npu,
            'power.total': self.power_total,
            'clock.npu': self.clock_npu,
            'clock.bus': self.clock_bus,
            'cores': {
                idx: {
                    'index': core.core_index,
                    'is_active': core.is_active,
                    'utilization': core.utilization,
                    'processes': [
                        {
                            'pid': p.pid,
                            'process_name': p.process_name,
                            'npu_memory': p.npu_memory,
                            'count': p.count,
                            'utilization': p.utilization,
                            'total_cores': p.total_cores,
                        }
                        for p in core.processes
                    ]
                }
                for idx, core in self.cores.items()
            },
            'processes': [
                {
                    'npu_index': p.npu_index,
                    'core_index': p.core_index,
                    'total_cores': p.total_cores,
                    'pid': p.pid,
                    'process_name': p.process_name,
                    'npu_memory': p.npu_memory,
                    'count': p.count,
                    'utilization': p.utilization,
                }
                for p in self.processes
            ]
        }


class NPUStatCollection(Sequence[NPUStat]):
    """
    Collection of NPU statistics.

    Represents all NPUs on the system with metadata.
    """

    def __init__(self,
                 npu_list: Sequence[NPUStat],
                 driver_versions: Optional[NPUDriverVersions] = None):
        self.npus = list(npu_list)
        self.hostname = platform.node()
        self.query_time = datetime.now()
        self.driver_versions = driver_versions or NPUDriverVersions()

    @staticmethod
    def new_query(debug=False) -> 'NPUStatCollection':
        """
        Query the information of all NPUs on local machine.

        Args:
            debug: Enable debug output

        Returns:
            NPUStatCollection with all NPU stats
        """
        try:
            npus, drivers = query_npu_status()
            npu_stats = [NPUStat(npu) for npu in npus]
            return NPUStatCollection(npu_stats, driver_versions=drivers)
        except RuntimeError as e:
            if debug:
                print(f"NPU query error: {e}", file=sys.stderr)
            return NPUStatCollection([], driver_versions=NPUDriverVersions())

    def __len__(self):
        return len(self.npus)

    def __iter__(self):
        return iter(self.npus)

    def __getitem__(self, index):
        return self.npus[index]

    def __repr__(self):
        s = f'NPUStatCollection(host={self.hostname}, [\n'
        s += '\n'.join('  ' + str(n) for n in self.npus)
        s += '\n])'
        return s

    @property
    def driver_version_str(self) -> str:
        """Format driver versions as a string."""
        parts = []
        if self.driver_versions.aries:
            parts.append(f"Aries:{self.driver_versions.aries}")
        if self.driver_versions.aries2:
            parts.append(f"Aries2:{self.driver_versions.aries2}")
        if self.driver_versions.regulus:
            parts.append(f"Regulus:{self.driver_versions.regulus}")
        return ' '.join(parts) if parts else 'N/A'

    def print_formatted(self, fp=sys.stdout, *,
                        force_color=False, no_color=False,
                        show_cmd=False, show_full_cmd=False, show_user=False,
                        show_pid=False, show_power=None, show_clock=False,
                        show_core_status=True,
                        npuname_width=None, show_header=True,
                        no_processes=False,
                        eol_char=os.linesep,
                        ):
        """
        Print formatted NPU statistics.

        Args:
            fp: File pointer to write to
            force_color: Force colored output
            no_color: Disable colored output
            show_cmd: Show command name
            show_full_cmd: Show full command line
            show_user: Show username
            show_pid: Show process IDs
            show_power: Show power consumption
            show_clock: Show clock frequencies
            show_core_status: Show per-core status
            npuname_width: Width for NPU name column
            show_header: Show header line
            no_processes: Hide process information
            eol_char: End of line character
        """
        if force_color and no_color:
            raise ValueError("--color and --no_color can't be used together")

        if force_color:
            TERM = os.getenv('TERM') or 'xterm-256color'
            t_color = Terminal(kind=TERM, force_styling=True)
            t_color._normal = '\x1b[0;10m'
        elif no_color:
            t_color = Terminal(force_styling=None)
        else:
            t_color = Terminal()

        # Header
        if show_header:
            if IS_WINDOWS:
                timestr = self.query_time.strftime('%Y-%m-%d %H:%M:%S')
            else:
                time_format = locale.nl_langinfo(locale.D_T_FMT)
                timestr = self.query_time.strftime(time_format)

            header_template = '{t.bold_magenta}[NPU]{t.normal} '
            header_template += '{t.bold_white}{hostname:{width}}{t.normal}  '
            header_template += '{timestr}  '
            header_template += '{t.bold_black}{driver_version}{t.normal}'

            header_msg = header_template.format(
                hostname=self.hostname,
                width=(npuname_width or DEFAULT_NPUNAME_WIDTH) + 3,
                timestr=timestr,
                driver_version=self.driver_version_str,
                t=t_color,
            )

            fp.write(header_msg.strip())
            fp.write(eol_char)

        # Body
        for n in self:
            n.print_to(fp,
                       show_cmd=show_cmd,
                       show_full_cmd=show_full_cmd,
                       no_processes=no_processes,
                       show_user=show_user,
                       show_pid=show_pid,
                       show_power=show_power,
                       show_clock=show_clock,
                       show_core_status=show_core_status,
                       npuname_width=npuname_width,
                       eol_char=eol_char,
                       term=t_color)
            # Core status가 표시되면 이미 줄바꿈이 포함됨
            if not show_core_status or not n.cores:
                fp.write(eol_char)

        if len(self.npus) == 0:
            pass  # No NPUs available, silently skip

        fp.flush()

    def jsonify(self) -> Dict[str, Any]:
        """Convert to JSON-serializable dictionary."""
        return {
            'hostname': self.hostname,
            'query_time': self.query_time,
            'driver_versions': {
                'aries': self.driver_versions.aries,
                'aries2': self.driver_versions.aries2,
                'regulus': self.driver_versions.regulus,
            },
            'npus': [n.jsonify() for n in self]
        }

    def print_json(self, fp=sys.stdout):
        """Print NPU stats as JSON."""
        def date_handler(obj):
            if hasattr(obj, 'isoformat'):
                return obj.isoformat()
            raise TypeError(type(obj))

        o = self.jsonify()
        json.dump(o, fp, indent=4, separators=(',', ': '),
                  default=date_handler)
        fp.write(os.linesep)
        fp.flush()


def new_npu_query() -> NPUStatCollection:
    """
    Obtain a new NPUStatCollection instance by querying mobilint-cli.

    Returns:
        NPUStatCollection with current NPU stats
    """
    return NPUStatCollection.new_query()
