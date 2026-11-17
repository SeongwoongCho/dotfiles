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
# Rows of queue a layout is chosen to leave room for; the queue itself then
# takes whatever the screen has left, down to its last job.
MIN_QUEUED_SHOWN = 5

# The two pool-wide rows: everything reserved over everything there is, and
# what a job submitted now could still get.
TOTAL_LABEL = 'Total'
FREE_LABEL = 'Available'

# Bumped whenever the cached shape changes, so an answer written by another
# version of npustat is ignored rather than misread.
CACHE_VERSION = 2
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
    # A waiting job names the host it asked for, or several it would take,
    # or none at all when any host will do.
    wants = raw.get('requested_nodes')
    if not isinstance(wants, list):
        wants = [raw.get('requested_node')]
    return {
        'name': _text(raw.get('name'), '?'),
        'node': _text(raw.get('node')),
        'wants': [n for n in map(_text, wants) if n],
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

    def open_total(self) -> Dict[str, float]:
        """The capacity of the hosts that accept jobs right now."""
        return {r: sum(n[r][1] for n in self.nodes if self.is_open(n))
                for r in RESOURCES}

    def not_open(self) -> str:
        """Why the totals hold more than can be used: '4 closed, 1 down'."""
        counts = [('closed', sum(1 for n in self.nodes if n['healthy']
                                 and not n['cordoned'] and n['closed'])),
                  ('cordoned', sum(1 for n in self.nodes
                                   if n['healthy'] and n['cordoned'])),
                  ('down', sum(1 for n in self.nodes if not n['healthy']))]
        return ', '.join('%d %s' % (c, what) for what, c in counts if c)

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
            'open_total': None if self.error else self.open_total(),
            'jobs': self.job_counts(),
            'queued': self.queued(),
            'nodes': [dict(n, open=self.is_open(n),
                           jobs=self.jobs_on(n['name']))
                      for n in self.nodes],
        }

    def queued(self) -> List[Dict[str, Any]]:
        """Waiting jobs, those after the same host(s) next to each other.

        Hosts queue separately, so this is what makes each one's backlog
        readable. The master's order is kept within a host, and the hosts
        come in the order of their first waiting job.
        """
        groups: Dict[Any, List[Dict[str, Any]]] = {}
        for j in self.jobs or []:
            if not j['running']:
                groups.setdefault(tuple(j['wants']), []).append(j)
        return [j for group in groups.values() for j in group]

    # ------------------------------------------------------------------ #

    def print_formatted(self, fp, *, term, eol_char=os.linesep,
                        size=None) -> None:
        """Write the section.

        size is (columns, rows) left for it when the caller knows the screen,
        e.g. under `watch` or in watch mode, where whatever does not fit is
        simply cut off. The full one-row-per-host table is used when it fits
        (or when size is None); otherwise the hosts are laid out compactly in
        as many side-by-side columns as it takes to fit the rows.
        The queue then takes the rows that are left: all of it when it fits
        (or when size is None), else as many jobs as there are rows for.
        """
        t = term
        cols, rows = size if size else (None, None)

        def line(text=''):
            fp.write(text.rstrip() + eol_char)

        def rule(text):
            return t.bold_black + text + t.normal

        def clip(text, width):
            if width is None or len(text) <= width:
                return text
            return text[:max(width - 1, 0)] + '…' if width > 0 else ''

        # The section opens with a titled rule, which is also what sets it
        # apart from this machine's own GPU/NPU lines above.
        title = (rule('── ') + t.bold_white + 'scheduler' + t.normal
                 + rule(' ── '))
        title_len = len('── scheduler ── ')
        if self.error:
            line('%s%sunavailable: %s%s' % (
                title, t.red,
                clip(self.error, cols and cols - title_len - 13), t.normal))
            return

        fleet, free = self.fleet(), self.free()
        nodes = self.nodes
        # Column widths follow the totals row, which holds the largest numbers.
        w = {r: len('%d' % round(max(fleet[r]))) for r in RESOURCES}
        name_w = max([len(n['name']) for n in nodes]
                     + [len(TOTAL_LABEL), len(FREE_LABEL)])
        queued = self.queued()
        queued_lines = (min(len(queued), MIN_QUEUED_SHOWN)
                        + (len(queued) > MIN_QUEUED_SHOWN))

        def load_color(used, total):
            if not total or not used:
                return ''
            pct = 100.0 * used / total
            return t.red if pct >= 90 else t.yellow if pct >= 50 else t.green

        def state(n, short=False):
            """What follows a host's numbers: (text, colour)."""
            if not n['healthy']:
                return 'down', t.bold_red
            if n['cordoned']:
                return 'cordoned', t.yellow
            if n['closed']:
                return ('closed' if short else n['closed']), t.yellow
            jobs = self.jobs_on(n['name'])
            if not jobs:
                return '', ''
            return '%d job%s' % (jobs, '' if jobs == 1 else 's'), ''

        def header(width):
            n_open = sum(1 for n in nodes if self.is_open(n))
            parts = ['%d/%d nodes open' % (n_open, len(nodes))]
            styled = list(parts)
            counts = self.job_counts()
            if counts is not None:
                q = '%d queued' % counts['queued']
                parts += ['%d running' % counts['running'], q]
                styled += [parts[1], t.bold_yellow + q + t.normal
                           if counts['queued'] else q]
            used = title_len + len(' · '.join(parts))
            legend = ' ── reserved / total '
            if cols is not None and used + len(legend) + 2 > cols:
                legend = ' '  # a narrow screen has no room for the legend
            used += len(legend)
            fill = max(width - used, 2)
            if cols is not None:
                fill = max(min(fill, cols - used), 0)
            line(title + ' · '.join(styled) + rule(legend + '─' * fill))

        def where(j):
            """The host a waiting job is after, as its queue line says it."""
            if len(j['wants']) == 1:
                return j['wants'][0]
            return '%d nodes' % len(j['wants']) if j['wants'] else 'any'

        def queue(room=None):
            # room: rows left for the queue, None when no screen bounds it.
            # Every job is listed when they fit; otherwise the last row says
            # how many are hidden.
            if room is None:
                room = len(queued)
            shown = min(len(queued), max(room, 0))
            if shown < len(queued):
                shown = max(shown - 1, 0)
            # The host each job waits for comes first, in a column of its
            # own, so one host's backlog reads straight down.
            where_w = max([len(where(j)) for j in queued] + [0])
            lead = len('  queued ') + where_w + 2
            for j in queued[:shown]:
                wants = ' '.join('%s=%s' % (k.rsplit('/', 1)[-1], v)
                                 for k, v in sorted(j['requests'].items()))
                what = clip('%s  %s' % (j['name'], wants),
                            cols and cols - lead)
                why = j['message'] or ''
                if cols is not None:
                    why = clip(why, cols - lead - len(what) - 2)
                why = '  ' + t.bold_black + why + t.normal if why else ''
                line('  %squeued%s %s%s%s  %s%s'
                     % (t.bold_yellow, t.normal, t.cyan,
                        where(j).ljust(where_w), t.normal, what, why))
            if shown < len(queued) and room > 0:
                line('  … and %d more queued' % (len(queued) - shown))

        # ---- full layout: one labelled row per host ------------------- #

        def cell_width(res):
            return (len(res) + 1 + 2 * w[res] + 1
                    + (3 if res == 'mem' else 0)
                    + (5 if res in ('cpu', 'mem') else 0))

        table_width = 2 + name_w + sum(3 + cell_width(r) for r in RESOURCES)
        # Total counts every host, usable or not; saying so on the row keeps
        # it from being read as what is on offer (that is Available's job).
        incl = self.not_open()
        incl = 'incl. ' + incl if incl else ''
        open_total = self.open_total()
        full_width = table_width + max(
            [2 + len(state(n)[0]) for n in nodes if state(n)[0]]
            + [2 + len(incl) if incl else 0])
        if size is None or (full_width <= cols
                            and 4 + len(nodes) + queued_lines <= rows):
            header(table_width)

            def cell(res, used, total, dim, free=False):
                unit = ' GB' if res == 'mem' else ''
                pct = res in ('cpu', 'mem')
                width = cell_width(res) - len(res) - 1
                if not total:
                    body = '-'
                else:
                    # A unit follows the memory total, so that one is right-
                    # aligned; the others pad on the right instead.
                    fmt = '%*d/%*d%s' if unit else '%*d/%-*d%s'
                    body = fmt % (w[res], round(used), w[res], round(total),
                                  unit)
                    if pct:
                        body += ' %3d%%' % min(round(100.0 * used / total),
                                               999)
                color = '' if dim else load_color(used, total)
                if free:
                    color = t.bold_cyan
                return '%s %s%s%s' % (res.upper(), color, body.ljust(width),
                                      t.normal if color else '')

            def row(name, cells, tail='', dim=False):
                head = (t.bold_black if dim else t.cyan) + name.ljust(name_w)
                sep = ' | '
                line('  %s%s%s%s%s' % (head, t.normal if not dim else '',
                                       sep, sep.join(cells),
                                       (t.normal if dim else '') + tail))

            row(TOTAL_LABEL, [cell(r, fleet[r][0], fleet[r][1], False)
                              for r in RESOURCES],
                '  ' + rule(incl) if incl else '')
            # Available reads the other way round: unreserved / capacity,
            # over the hosts that are open.
            row(FREE_LABEL, [cell(r, free[r], open_total[r], False, free=True)
                             for r in RESOURCES])
            # A thin rule between the pool-wide summary and the host rows.
            line('  ' + rule('─' * (name_w + 1) + '┼' + '┼'.join(
                '─' * (cell_width(r) + 2) for r in RESOURCES)[:-1]))
            for n in nodes:
                is_open = self.is_open(n)
                text, color = state(n)
                tail = ('  ' + color + text + (t.normal if color else '')
                        if text else '')
                row(n['name'], [cell(r, n[r][0], n[r][1], not is_open)
                                for r in RESOURCES], tail, dim=not is_open)
            queue(None if size is None else rows - 4 - len(nodes))
            return

        # ---- compact layout: hosts side by side ----------------------- #
        # The labels move into a heading and the percentages go (the colour
        # still tells the load), which makes a host narrow enough to stand
        # next to others; then as many columns are used as the rows require.

        labels = {'cpu': 'CPU', 'mem': 'MEM GB', 'gpu': 'GPU', 'npu': 'NPU'}
        # Reserved and total get a width each here: every character saved
        # per host is one a further column can use.
        wu = {r: len('%d' % round(max(fleet[r][0], free[r])))
              for r in RESOURCES}
        wt = {r: len('%d' % round(fleet[r][1])) for r in RESOURCES}
        cw = {r: max(wu[r] + 1 + wt[r], len(labels[r])) for r in RESOURCES}

        def arrange(tail_w):
            """(columns, block width) for hosts with a state this wide."""
            block_w = (name_w + sum(2 + cw[r] for r in RESOURCES)
                       + (2 + tail_w if tail_w else 0))
            most = max(1, (cols - 2 + 3) // (block_w + 3))
            most = min(most, max(len(nodes), 1))
            k = next((k for k in range(1, most + 1)
                      if 5 + -(-len(nodes) // k) + queued_lines <= rows),
                     most)
            return k, block_w

        # The state after each host (job count, closed, ...) is given up when
        # that is what lets one more column in; dimming still marks the hosts
        # that are not open.
        tail_w = max([len(state(n, short=True)[0]) for n in nodes] + [0])
        k, block_w = arrange(tail_w)
        if tail_w and 5 + -(-len(nodes) // k) > rows:
            bare = arrange(0)
            if bare[0] > k:
                (k, block_w), tail_w = bare, 0
        per_column = -(-len(nodes) // k)

        def block(name, values, tail=('', ''), dim=False):
            out = (t.bold_black if dim else t.cyan) + name.ljust(name_w)
            out += '' if dim else t.normal
            for r, (text, color) in zip(RESOURCES, values):
                color = '' if dim else color
                out += ('  ' + color + text.ljust(cw[r])
                        + (t.normal if color else ''))
            out += t.normal if dim else ''
            if tail_w:
                out += ('  ' + tail[1] + tail[0].ljust(tail_w)
                        + (t.normal if tail[1] else ''))
            return out

        def amount(res, used, total):
            if not total:
                return '-', ''
            return ('%*d/%-*d' % (wu[res], round(used), wt[res],
                                  round(total)), load_color(used, total))

        gap = ' ' + rule('│') + ' '
        header(2 + k * block_w + 3 * (k - 1))
        line('  ' + gap.join([block('', [(labels[r], t.bold_black)
                                         for r in RESOURCES])] * k))
        total_row = block(TOTAL_LABEL, [amount(r, *fleet[r])
                                        for r in RESOURCES])
        if incl and block_w - (tail_w if tail_w else -2) + len(incl) <= cols - 2:
            total_row = total_row.rstrip() + '  ' + rule(incl)
        line('  ' + total_row)
        line('  ' + block(FREE_LABEL, [
            (amount(r, free[r], open_total[r])[0], t.bold_cyan)
            for r in RESOURCES]))
        line('  ' + rule('┼'.join(['─' * (block_w + 2)] * k)[1:-1]))
        for i in range(per_column):
            line('  ' + gap.join(
                block(n['name'], [amount(r, *n[r]) for r in RESOURCES],
                      state(n, short=True), dim=not self.is_open(n))
                for n in nodes[i::per_column]))
        queue(rows - 5 - per_column)


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
