"""Shared pane traversal and snapshot writing for agent restore launchers."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile


def pane_session(root_pid, children, reader, commands=None):
    pending = [root_pid]
    seen = set()
    records = []
    while pending:
        pid = pending.pop()
        if pid in seen:
            continue
        seen.add(pid)
        record = reader(pid)
        if record is not None:
            records.append(record)
        elif Path((commands or {}).get(pid, "")).name not in {"claude", "codex"}:
            # A different agent (or an unreadable parent session) is a boundary.
            # Its tools can own separate PTYs with other interactive agents.
            pending.extend(children.get(pid, []))
    # Stop at the parent agent; never select one of its subprocess agents.
    return records[0] if len(records) == 1 else None


def save(snapshot, reader, marker, program):
    children = {}
    commands = {}
    for line in subprocess.check_output(["ps", "-axo", "pid=,ppid=,comm="], text=True).splitlines():
        pid_text, parent_text, command = line.split(None, 2)
        pid, parent = int(pid_text), int(parent_text)
        children.setdefault(parent, []).append(pid)
        commands[pid] = command
    panes = subprocess.check_output([
        "tmux", "list-panes", "-a", "-F",
        "#{session_name}\t#{window_index}\t#{pane_index}\t#{pane_pid}",
    ], text=True)
    records = {}
    for line in panes.splitlines():
        session, window, pane, pid = line.split("\t")
        record = pane_session(int(pid), children, reader, commands)
        if record is not None:
            records[(session, window, pane)] = record

    path = Path(snapshot)
    original = path.read_text()
    lines = []
    for line in original.splitlines(keepends=True):
        fields = line.rstrip("\n").split("\t")
        if len(fields) == 11 and fields[0] == "pane":
            record = records.get((fields[1], fields[2], fields[5]))
            if record is not None:
                # Hex survives resurrect's sed expansion and shell metacharacters.
                payload = json.dumps(record, sort_keys=True).encode().hex()
                fields[10] = f":{marker} {payload}"
                line = "\t".join(fields) + "\n"
            elif fields[9] == program or program in fields[10]:
                print(f"resurrect-{program}: no unambiguous session ID for "
                      f"{fields[1]}:{fields[2]}.{fields[5]}; restore will open the session picker",
                      file=sys.stderr)
        lines.append(line)
    updated = "".join(lines)
    if updated != original:
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as file:
                temporary = Path(file.name)
                file.write(updated)
            temporary.chmod(path.stat().st_mode & 0o777)
            temporary.replace(path)
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)
