"""Unit tests for the scheduler pool section (no network, no scheduler-cli)."""

import io
import json

import pytest
from blessed import Terminal

from npustat import scheduler


def raw_node(name, *, cpus=(0, 64), mem=(0, 256.4), gpus=(0, 2), npus=(0, 1),
             healthy=True, **extra):
    return dict({
        'node': name,
        'healthy': healthy,
        'capacity': {
            'total_cpus': cpus[1], 'cpus_held': cpus[0],
            'memory_total_gib': mem[1], 'memory_used_gib': mem[0],
            'gpus_total': gpus[1], 'gpus_held': gpus[0],
            'npus_total': npus[1], 'npus_held': npus[0],
        },
    }, **extra)


RAW_NODES = [
    raw_node('busy', cpus=(60, 64), mem=(128, 256.4), gpus=(2, 2)),
    raw_node('idle', gpus=(0, 0)),
    raw_node('shut', closed='closed for work hours until 22:00'),
    raw_node('dead', healthy=False),
    {'node': 'bare', 'healthy': False},  # never reported a capacity
]

RAW_JOBS = [
    {'name': 'a', 'node': 'busy', 'state': 'running',
     'requests': {'cpu': '8'}},
    {'name': 'b', 'node': 'busy', 'state': 'running',
     'requests': {'cpu': '8'}},
    {'name': 'waiting', 'state': 'queued', 'message': 'waiting for gpu',
     'requests': {'cpu': '4', 'nvidia.com/gpu': '1'}},
]


@pytest.fixture
def pool(monkeypatch, tmp_path):
    """A fake master; `calls` counts how often it was actually asked."""
    calls = {'nodes': 0}

    def fetch_nodes(endpoint, timeout):
        calls['nodes'] += 1
        return RAW_NODES

    monkeypatch.setenv('XDG_CACHE_HOME', str(tmp_path))
    monkeypatch.delenv('NPUSTAT_SCHEDULER_TTL', raising=False)
    monkeypatch.delenv('NPUSTAT_SCHEDULER_ENDPOINT', raising=False)
    monkeypatch.setattr(scheduler, '_fetch_nodes', fetch_nodes)
    monkeypatch.setattr(scheduler, '_fetch_jobs', lambda e, t: RAW_JOBS)
    return calls


def render(status):
    fp = io.StringIO()
    status.print_formatted(fp, term=Terminal(force_styling=None),
                           eol_char='\n')
    return fp.getvalue()


def test_fleet_counts_every_host_like_usage(pool):
    fleet = scheduler.new_query().fleet()
    assert fleet['cpu'] == [60, 64 * 4]
    assert fleet['gpu'] == [2, 6]
    assert fleet['npu'] == [0, 4]


def test_free_only_counts_hosts_that_accept_jobs(pool):
    # 'shut' and 'dead' have idle cores, but nothing can be placed there.
    free = scheduler.new_query().free()
    assert free['cpu'] == (64 - 60) + 64
    assert free['gpu'] == 0
    assert free['npu'] == 2


def test_job_counts_and_placement(pool):
    status = scheduler.new_query()
    assert status.job_counts() == {'running': 2, 'queued': 1}
    assert status.jobs_on('busy') == 2
    assert status.jobs_on('idle') == 0


def test_render(pool):
    lines = render(scheduler.new_query()).splitlines()
    assert lines[0].startswith('── scheduler ── 2/5 nodes open · 2 running'
                               ' · 1 queued ── reserved / total ──')
    assert len(lines[0]) >= len(lines[2])  # the rule spans the table
    # a thin rule parts the pool-wide rows from the hosts, crossing at each |
    assert set(lines[3].strip()) == {'─', '┼'}
    assert ([i for i, c in enumerate(lines[3]) if c == '┼']
            == [i for i, c in enumerate(lines[1]) if c == '|'])
    by_name = {ln.split()[0]: ln for ln in lines[1:]}
    assert 'CPU  60/256  23%' in by_name['Total']
    # Total counts hosts that take no jobs, and says so; Available is the
    # unreserved share of the open hosts' capacity
    assert by_name['Total'].endswith('incl. 1 closed, 2 down')
    assert 'CPU  68/128  53%' in by_name['Available']
    assert 'MEM  128/ 256 GB  50%' in by_name['busy']
    assert by_name['busy'].endswith('2 jobs')
    assert 'GPU -' in by_name['idle']
    assert by_name['shut'].endswith('closed for work hours until 22:00')
    assert by_name['dead'].endswith('down')
    assert by_name['bare'].endswith('down')
    assert by_name['queued'].split()[1:] == [
        'waiting', 'cpu=4', 'gpu=1', 'waiting', 'for', 'gpu']
    # every table row lines its separators up under the fleet row
    seps = [[i for i, c in enumerate(ln) if c == '|']
            for ln in lines[1:9] if '|' in ln]
    assert len(seps) == 7
    assert all(s == seps[0] for s in seps)


def test_job_counts_left_out_without_cli(pool, monkeypatch):
    monkeypatch.setattr(scheduler, '_fetch_jobs', lambda e, t: None)
    status = scheduler.new_query()
    assert status.job_counts() is None
    assert render(status).splitlines()[0].startswith(
        '── scheduler ── 2/5 nodes open ── reserved / total ──')


def test_answer_is_reused_within_ttl(pool):
    scheduler.new_query()
    scheduler.new_query()
    assert pool['nodes'] == 1


def test_ttl_zero_always_asks(pool, monkeypatch):
    monkeypatch.setenv('NPUSTAT_SCHEDULER_TTL', '0')
    scheduler.new_query()
    scheduler.new_query()
    assert pool['nodes'] == 2


def test_cache_is_per_endpoint(pool, monkeypatch):
    scheduler.new_query()
    monkeypatch.setenv('NPUSTAT_SCHEDULER_ENDPOINT', 'http://other/adm/')
    assert scheduler.new_query().endpoint == 'http://other/adm'
    assert pool['nodes'] == 2


def test_unreachable_master_is_reported_not_raised(pool, monkeypatch):
    def refuse(endpoint, timeout):
        pool['nodes'] += 1
        raise OSError('connection refused')

    monkeypatch.setattr(scheduler, '_fetch_nodes', refuse)
    status = scheduler.new_query()
    assert render(status) == ('── scheduler ── unavailable: '
                              'connection refused\n')
    assert status.jsonify()['error'] == 'connection refused'
    # the failure is cached too: one timeout per TTL, not one per call
    scheduler.new_query()
    assert pool['nodes'] == 1


def test_jsonify_is_serialisable(pool):
    out = json.loads(json.dumps(scheduler.new_query().jsonify()))
    assert out['jobs'] == {'running': 2, 'queued': 1}
    assert [n['name'] for n in out['nodes'] if n['open']] == ['busy', 'idle']
    assert out['queued'][0]['name'] == 'waiting'


def test_odd_answers_never_reach_the_arithmetic(pool, monkeypatch):
    # Wrong types, missing pieces and terminal escapes, as a master of another
    # version (or a broken one) might send them.
    monkeypatch.setattr(scheduler, '_fetch_nodes', lambda e, t: [
        None, 'text', {'node': 7, 'healthy': True, 'capacity': 'none'},
        raw_node('odd', cpus=('1000', '4'), mem=(None, 'x'), gpus=(3, 0),
                 closed='shut\x1b[2J\nnow'),
    ])
    monkeypatch.setattr(scheduler, '_fetch_jobs', lambda e, t: [
        None, 1, {'name': 'q\nq', 'state': 'queued', 'requests': ['cpu'],
                  'message': 5},
    ])
    status = scheduler.new_query()
    text = render(status)
    json.dumps(status.jsonify())
    assert '\x1b' not in text
    assert len(text.splitlines()) == 4 + 4 + 3
    assert 'shut [2J now' in text
    assert status.fleet()['cpu'] == [1000, 4]
    seps = [[i for i, c in enumerate(ln) if c == '|']
            for ln in text.splitlines()[1:8] if '|' in ln]
    assert len(seps) == 6
    assert all(s == seps[0] for s in seps)


def test_cache_from_another_version_is_ignored(pool, tmp_path):
    scheduler.new_query()
    path = tmp_path / 'npustat' / 'scheduler.json'
    data = json.loads(path.read_text())
    data.update(v=scheduler.CACHE_VERSION + 1, nodes=[{'name': 'x'}])
    path.write_text(json.dumps(data))
    assert len(scheduler.new_query().nodes) == len(RAW_NODES)
    assert pool['nodes'] == 2


def test_unknown_pool_is_null_in_json_not_zero(pool, monkeypatch):
    def refuse(endpoint, timeout):
        raise OSError('down')

    monkeypatch.setattr(scheduler, '_fetch_nodes', refuse)
    out = scheduler.new_query().jsonify()
    assert out['fleet'] is None and out['free'] is None


def many_nodes(monkeypatch, n=16):
    monkeypatch.setattr(scheduler, '_fetch_nodes', lambda e, t: [
        raw_node('server%02d' % i, cpus=(i, 64),
                 closed='closed for work hours' if i % 5 == 0 else None)
        for i in range(n)])
    monkeypatch.setattr(scheduler, '_fetch_jobs', lambda e, t: [])


def render_in(status, cols, rows):
    fp = io.StringIO()
    status.print_formatted(fp, term=Terminal(force_styling=None),
                           eol_char='\n', size=(cols, rows))
    return fp.getvalue().splitlines()


def test_full_table_is_kept_when_the_screen_has_room(pool, monkeypatch):
    many_nodes(monkeypatch)
    status = scheduler.new_query()
    assert render_in(status, 200, 50) == render(status).splitlines()


@pytest.mark.parametrize('cols, rows, columns', [
    (120, 13, 2),   # too short for 16 rows: two columns of 8
    (200, 11, 3),   # shorter still, and wide enough for three
    (60, 40, 1),    # too narrow for the full table: compact, one column
])
def test_hosts_move_into_columns_to_fit(pool, monkeypatch,
                                        cols, rows, columns):
    many_nodes(monkeypatch)
    lines = render_in(scheduler.new_query(), cols, rows)
    assert len(lines) <= rows
    assert max(map(len, lines)) <= cols
    assert lines[1].split().count('CPU') == columns
    text = '\n'.join(lines)
    assert all('server%02d' % i in text for i in range(16))
    # hosts read down each column, in name order
    per_column = -(-16 // columns)
    assert lines[5].split('│')[0].split()[0] == 'server00'
    if columns > 1:
        assert (lines[5].split('│')[1].split()[0]
                == 'server%02d' % per_column)


def test_host_state_is_dropped_when_it_buys_a_column(pool, monkeypatch):
    many_nodes(monkeypatch)
    status = scheduler.new_query()
    roomy = render_in(status, 120, 13)
    tight = [cols for cols in range(60, 120)
             if 'closed' not in '\n'.join(render_in(status, cols, 13)[5:])
             and render_in(status, cols, 13)[1].count('CPU') == 2]
    assert 'closed' in '\n'.join(roomy[5:])
    assert tight  # some widths fit two columns only without the state


def test_queue_gives_way_to_hosts_on_a_short_screen(pool, monkeypatch):
    many_nodes(monkeypatch)
    monkeypatch.setattr(scheduler, '_fetch_jobs', lambda e, t: [
        {'name': 'q%d' % i, 'state': 'queued'} for i in range(4)])
    lines = render_in(scheduler.new_query(), 120, 14)
    assert len(lines) <= 14
    assert lines[-1].strip() == '… and 4 more queued'


def test_redraw_reuses_what_was_queried(monkeypatch, capsys):
    from npustat import cli
    asked = []
    monkeypatch.setattr(cli, '_query_stats',
                        lambda **kw: asked.append(kw) or (None, None, None))
    stats = {}
    cli.print_gpustat(_stats=stats)
    cli.print_gpustat(_stats=stats)   # a redraw, e.g. after a resize
    assert len(asked) == 1
    stats.clear()                     # the interval ran out
    cli.print_gpustat(_stats=stats)
    assert len(asked) == 2
    capsys.readouterr()


def test_resize_ends_the_wait_early():
    import os
    import signal
    import time
    from npustat import cli
    old_handler = signal.getsignal(signal.SIGWINCH)
    watch = cli._ResizeWatch()
    try:
        start = time.time()
        assert watch.wait(0.05) is False
        assert time.time() - start >= 0.04
        os.kill(os.getpid(), signal.SIGWINCH)
        start = time.time()
        assert watch.wait(5) is True
        assert time.time() - start < 1
    finally:
        signal.set_wakeup_fd(-1)
        signal.signal(signal.SIGWINCH, old_handler)


def test_total_is_not_annotated_when_every_host_is_open(pool, monkeypatch):
    monkeypatch.setattr(scheduler, '_fetch_nodes',
                        lambda e, t: [raw_node('a'), raw_node('b')])
    status = scheduler.new_query()
    assert 'incl.' not in render(status)
    assert 'incl.' not in '\n'.join(render_in(status, 60, 5))
    assert status.jsonify()['open_total']['cpu'] == 128
