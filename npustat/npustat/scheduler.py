"""Reservation status of the shared compute pool behind ``scheduler-cli``.

The pool's master serves every host's capacity as JSON at ``<endpoint>/nodes``;
that is read directly, so the section works without the CLI installed. The
job counts come from ``scheduler-cli ps --json`` (the master's own job list
also carries every finished job, several MB of it) and are simply left out
when the CLI is missing or too old to know ``--json``.

Everything shown is a *reservation*, not live utilisation: a job that holds
eight cores counts as eight whether or not it keeps them busy.
"""

import json
import os
import re
import shutil
import subprocess
import tempfile
import time
import urllib.request
from typing import Any, Dict, List, Optional

DEFAULT_ENDPOINT = 'https://scheduler.mobilint.com/adm'

# `watch -n.5 npustat` would otherwise ask the master twice a second; answers
# (failures included) are reused across processes for this many seconds.
DEFAULT_TTL = 5.0

RESOURCES = ('cpu', 'mem', 'gpu', 'npu')
MAX_QUEUED_SHOWN = 5

# The two pool-wide rows: everything reserved over everything there is, and
# what a job submitted now could still get.
TOTAL_LABEL = 'Total'
FREE_LABEL = 'Available'

# Bumped whenever the cached shape changes, so an answer written by another
# version of npustat is ignored rather than misread.
CACHE_VERSION = 1
MAX_RESPONSE_BYTES = 8 << 20

_CONTROL_CHARS = re.compile(r'[\x00-\x1f\x7f-\x9f]+')


def _text(value: Any, default: Optional[str] = None) -> Optional[str]:
    """The master's words as one printable line (they go to a terminal)."""
    if value is None or value == '' or isinstance(value, (dict, list)):
        return default
    return _CONTROL_CHARS.sub(' ', str(value)).strip() or default


def _number(value: Any) -> float:
    try:
        n = float(value)
    except (TypeError, ValueError):
        return 0
    return n if 0 <= n < float('inf') else 0


def _endpoint() -> str:
    return (os.environ.get('NPUSTAT_SCHEDULER_ENDPOINT')
            or DEFAULT_ENDPOINT).rstrip('/')


def _ttl() -> float:
    try:
        return float(os.environ['NPUSTAT_SCHEDULER_TTL'])
    except (KeyError, ValueError):
        return DEFAULT_TTL


def _cache_path() -> str:
    base = (os.environ.get('XDG_CACHE_HOME')
            or os.path.join(os.path.expanduser('~'), '.cache'))
    return os.path.join(base, 'npustat', 'scheduler.json')


def _read_cache(endpoint: str, ttl: float) -> Optional[Dict[str, Any]]:
    if ttl <= 0:
        return None
    try:
        with open(_cache_path(), encoding='utf-8') as f:
            data = json.load(f)
        age = time.time() - data['fetched_at']
        if (data['v'] == CACHE_VERSION and data['endpoint'] == endpoint
                and 0 <= age < ttl):
            return data
    except (OSError, ValueError, KeyError, TypeError):
        pass
    return None


def _write_cache(data: Dict[str, Any]) -> None:
    path = _cache_path()
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        # Written aside and renamed, so a concurrent reader never sees half.
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), suffix='.tmp')
        try:
            with os.fdopen(fd, 'w', encoding='utf-8') as f:
                json.dump(data, f)
            os.replace(tmp, path)
        except BaseException:
            os.unlink(tmp)
            raise
    except OSError:
        pass  # a cache that cannot be written only costs the next query


def _fetch_nodes(endpoint: str, timeout: float) -> List[Dict[str, Any]]:
    with urllib.request.urlopen(endpoint + '/nodes', timeout=timeout) as r:
        nodes = json.loads(r.read(MAX_RESPONSE_BYTES))
    if not isinstance(nodes, list):
        raise ValueError('unexpected answer from %s/nodes' % endpoint)
    return nodes


def _fetch_jobs(endpoint: str, timeout: float) -> Optional[List[Dict[str, Any]]]:
    """Queued and running jobs, or None when the CLI cannot tell us."""
    cli = shutil.which('scheduler-cli')
    if cli is None:
        return None
    try:
        out = subprocess.run(
            [cli, 'ps', '--json', '--endpoint', endpoint],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            timeout=timeout, check=True,
        ).stdout
        jobs = json.loads(out)
    except (OSError, subprocess.SubprocessError, ValueError):
        return None
    return jobs if isinstance(jobs, list) else None


def _slim_node(raw: Any) -> Dict[str, Any]:
    # Every value is coerced here, so that whatever the master sends, the
    # arithmetic and formatting further down only ever meet numbers and text.
    if not isinstance(raw, dict):
        raw = {}
    cap = raw.get('capacity')
    if not isinstance(cap, dict):
        cap = {}

    def pair(used_key, total_key):
        return [_number(cap.get(used_key)), _number(cap.get(total_key))]

    return {
        'name': _text(raw.get('node')) or _text(cap.get('node'), '?'),
        'healthy': bool(raw.get('healthy')),
        'cordoned': bool(raw.get('cordoned')),
        'closed': _text(raw.get('closed')),
        'cpu': pair('cpus_held', 'total_cpus'),
        'mem': pair('memory_used_gib', 'memory_total_gib'),
        'gpu': pair('gpus_held', 'gpus_total'),
        'npu': pair('npus_held', 'npus_total'),
    }


def _slim_job(raw: Any) -> Dict[str, Any]:
    if not isinstance(raw, dict):
        raw = {}
    requests = raw.get('requests')
    if not isinstance(requests, dict):
        requests = {}
    return {
        'name': _text(raw.get('name'), '?'),
        'node': _text(raw.get('node')),
        'running': raw.get('state') == 'running',
        'priority': _number(raw.get('priority')),
        'requests': {_text(k, '?'): _text(v, '?')
                     for k, v in requests.items()},
        'message': _text(raw.get('message')),
    }


class SchedulerStatus:
    """A snapshot of the pool: per-host reservations plus the job queue."""

    def __init__(self, data: Dict[str, Any]):
        self.endpoint: str = data['endpoint']
        self.fetched_at: float = data['fetched_at']
        self.error: Optional[str] = data.get('error')
        self.nodes: List[Dict[str, Any]] = sorted(
            data.get('nodes') or [], key=lambda n: n['name'])
        self.jobs: Optional[List[Dict[str, Any]]] = data.get('jobs')

    @staticmethod
    def is_open(node: Dict[str, Any]) -> bool:
        """Whether the master would place a new job on this host now."""
        return (node['healthy'] and not node['cordoned']
                and not node['closed'])

    def fleet(self) -> Dict[str, List[float]]:
        """[reserved, total] per resource over every host, as `usage` does."""
        return {r: [sum(n[r][0] for n in self.nodes),
                    sum(n[r][1] for n in self.nodes)] for r in RESOURCES}

    def free(self) -> Dict[str, float]:
        """What is unreserved on hosts that accept jobs right now."""
        return {r: sum(max(n[r][1] - n[r][0], 0)
                       for n in self.nodes if self.is_open(n))
                for r in RESOURCES}

    def job_counts(self) -> Optional[Dict[str, int]]:
        if self.jobs is None:
            return None
        running = sum(1 for j in self.jobs if j['running'])
        return {'running': running, 'queued': len(self.jobs) - running}

    def jobs_on(self, node_name: str) -> int:
        return sum(1 for j in self.jobs or []
                   if j['running'] and j['node'] == node_name)

    def jsonify(self) -> Dict[str, Any]:
        return {
            'endpoint': self.endpoint,
            'query_time': self.fetched_at,
            'error': self.error,
            # null, not zeros, when nothing is known: 0 free would be a claim
            'fleet': None if self.error else self.fleet(),
            'free': None if self.error else self.free(),
            'jobs': self.job_counts(),
            'queued': [j for j in self.jobs or [] if not j['running']],
            'nodes': [dict(n, open=self.is_open(n),
                           jobs=self.jobs_on(n['name']))
                      for n in self.nodes],
        }

    # ------------------------------------------------------------------ #

    def print_formatted(self, fp, *, term, eol_char=os.linesep) -> None:
        t = term

        def line(text=''):
            fp.write(text.rstrip() + eol_char)

        def rule(text):
            return t.bold_black + text + t.normal

        # The section opens with a titled rule, which is also what sets it
        # apart from this machine's own GPU/NPU lines above.
        title = (rule('── ') + t.bold_white + 'scheduler' + t.normal
                 + rule(' ── '))
        if self.error:
            line('%s%sunavailable: %s%s'
                 % (title, t.red, self.error, t.normal))
            return

        fleet, free = self.fleet(), self.free()
        # Column widths follow the totals row, which holds the largest numbers.
        w = {r: len('%d' % round(max(fleet[r]))) for r in RESOURCES}
        name_w = max([len(n['name']) for n in self.nodes]
                     + [len(TOTAL_LABEL), len(FREE_LABEL)])

        def cell_width(res):
            return (len(res) + 1 + 2 * w[res] + 1
                    + (3 if res == 'mem' else 0)
                    + (5 if res in ('cpu', 'mem') else 0))

        table_width = 2 + name_w + sum(3 + cell_width(r) for r in RESOURCES)

        n_open = sum(1 for n in self.nodes if self.is_open(n))
        parts = ['%d/%d nodes open' % (n_open, len(self.nodes))]
        styled = list(parts)
        counts = self.job_counts()
        if counts is not None:
            queued = '%d queued' % counts['queued']
            parts += ['%d running' % counts['running'], queued]
            styled += [parts[1], t.bold_yellow + queued + t.normal
                       if counts['queued'] else queued]
        legend = ' ── reserved / total '
        used = (len('── scheduler ── ') + len(' · '.join(parts))
                + len(legend))
        line(title + ' · '.join(styled)
             + rule(legend + '─' * max(table_width - used, 2)))

        def load_color(used, total):
            if not total or not used:
                return ''
            pct = 100.0 * used / total
            return t.red if pct >= 90 else t.yellow if pct >= 50 else t.green

        def cell(res, used, total, dim):
            label = res.upper()
            unit = ' GB' if res == 'mem' else ''
            pct = res in ('cpu', 'mem')
            width = 2 * w[res] + 1 + len(unit) + (5 if pct else 0)
            if not total:
                body = '-'
            else:
                # A unit follows the memory total, so that one is right-
                # aligned; the others pad on the right instead.
                fmt = '%*d/%*d%s' if unit else '%*d/%-*d%s'
                body = fmt % (w[res], round(used), w[res], round(total), unit)
                if pct:
                    body += ' %3d%%' % min(round(100.0 * used / total), 999)
            color = '' if dim else load_color(used, total)
            return '%s %s%s%s' % (label, color, body.ljust(width),
                                  t.normal if color else '')

        def free_cell(res, amount):
            unit = ' GB' if res == 'mem' else ''
            pct = res in ('cpu', 'mem')
            width = 2 * w[res] + 1 + len(unit) + (5 if pct else 0)
            body = '%*d%s' % (w[res], round(amount), unit)
            return '%s %s%s%s' % (res.upper(), t.bold_cyan,
                                  body.ljust(width), t.normal)

        def row(name, cells, tail='', dim=False):
            head = (t.bold_black if dim else t.cyan) + name.ljust(name_w)
            sep = ' | '
            body = sep.join(cells)
            line('  %s%s%s%s%s' % (head, t.normal if not dim else '',
                                   sep, body,
                                   (t.normal if dim else '') + tail))

        row(TOTAL_LABEL, [cell(r, fleet[r][0], fleet[r][1], False)
                          for r in RESOURCES])
        row(FREE_LABEL, [free_cell(r, free[r]) for r in RESOURCES])
        # A thin rule between the pool-wide summary and the per-host rows.
        line('  ' + rule('─' * (name_w + 1) + '┼' + '┼'.join(
            '─' * (cell_width(r) + 2) for r in RESOURCES)[:-1]))

        for n in self.nodes:
            is_open = self.is_open(n)
            if not n['healthy']:
                tail = '  ' + t.bold_red + 'down' + t.normal
            elif n['cordoned']:
                tail = '  ' + t.yellow + 'cordoned' + t.normal
            elif n['closed']:
                tail = '  ' + t.yellow + str(n['closed']) + t.normal
            else:
                jobs = self.jobs_on(n['name'])
                tail = '  %d job%s' % (jobs, '' if jobs == 1 else 's') \
                    if jobs else ''
            row(n['name'], [cell(r, n[r][0], n[r][1], not is_open)
                            for r in RESOURCES], tail, dim=not is_open)

        queued = [j for j in self.jobs or [] if not j['running']]
        for j in queued[:MAX_QUEUED_SHOWN]:
            wants = ' '.join('%s=%s' % (k.rsplit('/', 1)[-1], v)
                             for k, v in sorted(j['requests'].items()))
            why = ('  ' + t.bold_black + j['message'] + t.normal
                   if j['message'] else '')
            line('  %squeued%s %s  %s%s'
                 % (t.bold_yellow, t.normal, j['name'], wants, why))
        if len(queued) > MAX_QUEUED_SHOWN:
            line('  … and %d more queued' % (len(queued) - MAX_QUEUED_SHOWN))


def new_query(timeout: float = 2.0) -> SchedulerStatus:
    """Query the pool, reusing a recent answer when there is one.

    Never raises for an unreachable master: the failure is carried in
    ``SchedulerStatus.error`` (and cached like any other answer, so an
    unreachable master costs one timeout per TTL rather than one per call).
    """
    endpoint, ttl = _endpoint(), _ttl()
    data = _read_cache(endpoint, ttl)
    if data is None:
        data = {'v': CACHE_VERSION, 'endpoint': endpoint,
                'fetched_at': time.time(),
                'nodes': [], 'jobs': None, 'error': None}
        try:
            data['nodes'] = [_slim_node(n)
                             for n in _fetch_nodes(endpoint, timeout)]
        except Exception as e:  # pylint: disable=broad-exception-caught
            data['error'] = _text(e, type(e).__name__)
        else:
            jobs = _fetch_jobs(endpoint, timeout)
            if jobs is not None:
                data['jobs'] = [_slim_job(j) for j in jobs]
        _write_cache(data)
    return SchedulerStatus(data)
