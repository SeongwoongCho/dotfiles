"""Codex identity discovery and launch tests, without real model requests."""

import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import shlex
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tmux"))
SCRIPT = ROOT / "tmux/resurrect-codex"
LOADER = importlib.machinery.SourceFileLoader("resurrect_codex", str(SCRIPT))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
CODEX = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(CODEX)
FIRST = "11111111-1111-4111-8111-111111111111"
SECOND = "22222222-2222-4222-8222-222222222222"
CHILD = "33333333-3333-4333-8333-333333333333"


class CodexRestoreTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.home = self.base / "codex home & [test]"
        (self.home / "sessions").mkdir(parents=True)
        (self.home / "thread-writer-locks").mkdir()
        self.cwd = self.base / "project & [1m] $(touch INJECTED)"
        self.cwd.mkdir()
        self.proc = self.base / "proc"
        self.proc.mkdir()
        self.log = self.base / "launch.jsonl"
        self.bin = self.base / "bin"
        self.bin.mkdir()
        for executable in ("codex", "ocx"):
            path = self.bin / executable
            path.write_text(f"#!{sys.executable}\n" + '''import json, os, pathlib, sys
with open(os.environ["LAUNCH_LOG"], "a") as log:
    log.write(json.dumps({"program": pathlib.Path(sys.argv[0]).name, "args": sys.argv[1:],
                         "cwd": os.getcwd(), "codex_home": os.environ.get("CODEX_HOME")}) + "\\n")
if pathlib.Path(sys.argv[0]).name == "ocx":
    sys.exit(int(os.environ.get("OCX_EXIT", "0")))
''')
            path.chmod(0o755)
        self.env = {**os.environ, "HOME": str(self.base), "CODEX_HOME": str(self.home),
                    "PATH": f"{self.bin}:{os.environ['PATH']}", "LAUNCH_LOG": str(self.log)}

    def record(self, session_id=FIRST):
        return {"session_id": session_id, "cwd": str(self.cwd), "codex_home": str(self.home),
                "flags": ["--yolo", "--search", "--disable", "fast_mode"], "ocx": True}

    def process(self, pid=11, foreground=True):
        process = self.proc / str(pid)
        (process / "fd").mkdir(parents=True, exist_ok=True)
        (process / "comm").write_text("codex\n")
        stat = ["0"] * 20
        stat[0], stat[2], stat[5], stat[19] = "S", "100", "100" if foreground else "200", "123"
        (process / "stat").write_text(f"{pid} (codex) " + " ".join(stat))
        (process / "environ").write_bytes(
            f"CODEX_HOME={self.home}\0OCX_SHIM_ACTIVE_PID=10\0OPENAI_API_KEY=not-for-snapshot\0".encode())
        (process / "cmdline").write_bytes(b"/usr/bin/codex\0--yolo\0--search\0--disable\0fast_mode\0")
        return process

    def thread(self, process, session_id=FIRST, source="cli", lock=True, header=True, database=True):
        fd = process / "fd"
        index = len(list(fd.iterdir())) + 10
        if lock:
            path = self.home / "thread-writer-locks" / f"{session_id}.lock"
            path.touch()
            (fd / str(index)).symlink_to(path)
            index += 1
        if header:
            # The file name intentionally differs from the actual thread identity.
            path = self.home / "sessions" / f"rollout-replayed-{session_id}_other-uuid.jsonl"
            path.write_text(json.dumps({"type": "session_meta", "payload": {
                "id": session_id, "cwd": str(self.cwd), "source": source}}) + "\nprivate body\n")
            (fd / str(index)).symlink_to(path)
        if database:
            with sqlite3.connect(self.home / "state_5.sqlite") as db:
                db.execute("CREATE TABLE IF NOT EXISTS threads (id TEXT PRIMARY KEY, cwd TEXT, source TEXT)")
                db.execute("INSERT OR REPLACE INTO threads VALUES (?, ?, ?)",
                           (session_id, str(self.cwd), source if isinstance(source, str) else json.dumps(source)))

    def launches(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def launch(self, record=None, args=None, env=None):
        args = args if args is not None else ["--restore", json.dumps(record or self.record()).encode().hex()]
        return subprocess.run([str(SCRIPT), *args], cwd=self.cwd, env=env or self.env,
                              text=True, capture_output=True)

    def test_live_root_selected_without_subagents_or_filename_guessing(self):
        process = self.process()
        self.thread(process)
        self.thread(process, CHILD, source={"subagent": {"parent_thread_id": FIRST}})
        self.assertEqual(CODEX.session_record(11, self.proc), self.record())

    def test_paginated_thread_with_only_open_lock_uses_readonly_database(self):
        process = self.process()
        self.thread(process, header=False)
        before = (self.home / "state_5.sqlite").read_bytes()
        self.assertEqual(CODEX.session_record(11, self.proc), self.record())
        self.assertEqual((self.home / "state_5.sqlite").read_bytes(), before)

    def test_older_rollout_without_lock_or_database_is_supported(self):
        process = self.process()
        self.thread(process, lock=False, database=False)
        self.assertEqual(CODEX.session_record(11, self.proc), self.record())

    def test_stale_lock_files_and_inactive_rollouts_do_not_select_another_thread(self):
        process = self.process()
        self.thread(process)
        self.thread(process, SECOND, lock=False)
        (self.home / "thread-writer-locks" / f"{SECOND}.lock").touch()
        self.assertEqual(CODEX.session_record(11, self.proc), self.record())

    def test_multiple_cli_threads_background_or_unpersisted_thread_are_not_guessed(self):
        process = self.process()
        self.thread(process)
        self.thread(process, SECOND)
        self.assertIsNone(CODEX.session_record(11, self.proc))
        process = self.process(12, foreground=False)
        self.thread(process)
        self.assertIsNone(CODEX.session_record(12, self.proc))
        process = self.process(13)
        self.thread(process, CHILD, header=False, database=False)
        self.assertIsNone(CODEX.session_record(13, self.proc))
        self.assertIsNone(CODEX.session_record(999, self.proc))

    def test_exact_restore_ensures_ocx_then_uses_installed_codex_launcher(self):
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        launches = self.launches()
        self.assertEqual([row["program"] for row in launches], ["ocx", "codex"])
        self.assertEqual(launches[0]["args"], ["ensure"])
        self.assertEqual(launches[1]["args"], [*self.record()["flags"], "resume", FIRST])
        self.assertTrue(all(row["codex_home"] == str(self.home) for row in launches))
        self.assertTrue(all(row["cwd"] == str(self.cwd) for row in launches))
        self.assertFalse((self.cwd / "INJECTED").exists())

    def test_native_session_does_not_start_ocx(self):
        record = {**self.record(), "ocx": False, "flags": ["--sandbox", "read-only"]}
        result = self.launch(record)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([row["program"] for row in self.launches()], ["codex"])
        self.assertNotIn("--yolo", self.launches()[0]["args"])

    def test_ocx_failure_prevents_codex_launch(self):
        result = self.launch(env={**self.env, "OCX_EXIT": "23"})
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual([row["program"] for row in self.launches()], ["ocx"])

    def test_legacy_save_uses_picker_not_last(self):
        result = self.launch(args=[])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("choose the conversation", result.stderr)
        self.assertEqual(self.launches()[0]["args"], ["resume"])

    def test_launch_flags_preserve_policy_without_replaying_prompts_and_secrets(self):
        flags = CODEX.launch_flags(["--yolo", "--config", "api_key=private", "--model", "old",
                                   "resume", FIRST, "--search", "--disable=fast_mode",
                                   "--profile", "my profile", "delete files --yolo"])
        self.assertEqual(flags, ["--yolo", "--search", "--disable", "fast_mode", "--profile", "my profile"])
        self.assertEqual(CODEX.launch_flags(["--", "--yolo"]), [])

    def test_invalid_restore_record_cannot_launch(self):
        invalid = ["bad-hex", "6e756c6c", json.dumps({**self.record(), "flags": ["--last"]}).encode().hex(),
                   json.dumps({**self.record(), "cwd": str(self.base / "missing")}).encode().hex()]
        for payload in invalid:
            with self.subTest(payload=payload):
                result = self.launch(args=["--restore", payload])
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.log.exists())

    def test_two_wrapped_panes_in_same_directory_get_different_records(self):
        self.thread(self.process(12), FIRST)
        self.thread(self.process(22), SECOND)
        snapshot = self.base / "snapshot"
        def pane(index):
            return f"pane\twork\t1\t1\t:*\t{index}\ttitle\t:/same\t1\tnode\t:node codex.opencodex-real\n"
        untouched = "pane\twork\t2\t1\t:*\t1\ttitle\t:/same\t1\tclaude\t:dotfiles-cc-resume abc\n"
        snapshot.write_text(pane(1) + pane(2) + untouched)
        outputs = ["10 1 zsh\n11 10 node\n12 11 codex\n20 1 zsh\n21 20 node\n22 21 codex\n",
                   "work\t1\t1\t10\nwork\t1\t2\t20\n"]
        reader = CODEX.session_record
        with mock.patch.object(CODEX.subprocess, "check_output", side_effect=outputs), \
                mock.patch.object(CODEX, "session_record", side_effect=lambda pid: reader(pid, self.proc)):
            CODEX.save(snapshot)
        saved = snapshot.read_text()
        self.assertTrue(saved.endswith(untouched))
        self.assertNotIn("not-for-snapshot", saved)
        for line, session_id in zip(saved.splitlines(), (FIRST, SECOND)):
            marker, payload = line.split("\t")[10][1:].split()
            self.assertEqual(marker, CODEX.MARKER)
            self.assertEqual(json.loads(bytes.fromhex(payload))["session_id"], session_id)

    def test_parent_agents_block_discovery_of_tool_launched_sessions(self):
        reader = mock.Mock(side_effect=lambda pid: self.record() if pid == 13 else None)
        for parent in ("claude", "codex"):
            with self.subTest(parent=parent):
                reader.reset_mock()
                result = CODEX.resurrect_sessions.pane_session(
                    10, {10: [11], 11: [12], 12: [13]}, reader,
                    {10: "zsh", 11: parent, 12: "bash", 13: "codex"})
                self.assertIsNone(result)
                self.assertNotIn(mock.call(13), reader.call_args_list)

    @unittest.skipUnless(shutil.which("zsh"), "zsh is not installed")
    def test_real_resurrect_mapping_and_zsh_quoting(self):
        plugin = Path.home() / ".tmux/plugins/tmux-resurrect/scripts"
        if not (plugin / "process_restore_helpers.sh").exists():
            self.skipTest("tmux-resurrect is not installed")
        option = next(line for line in (ROOT / "tmux/tmux.conf").read_text().splitlines()
                      if line.startswith("set -g @resurrect-processes "))
        payload = json.dumps(self.record()).encode().hex()
        env = {**self.env, "RESTORE_LIST": shlex.split(option)[3],
               "SAVED_COMMAND": f"{CODEX.MARKER} {payload}"}
        script = '''source "$1/variables.sh"
source "$1/helpers.sh"
source "$1/process_restore_helpers.sh"
get_tmux_option() { [[ "$1" == "@resurrect-processes" ]] && echo "$RESTORE_LIST"; }
_get_inline_strategy "$SAVED_COMMAND"
'''
        result = subprocess.run(["bash", "-c", script, "bash", str(plugin)], env=env,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), f"~/.dotfiles/tmux/resurrect-codex --restore {payload}")
        command = result.stdout.strip().replace("~/.dotfiles/tmux/resurrect-codex", shlex.quote(str(SCRIPT)), 1)
        result = subprocess.run(["zsh", "-f", "-c", command], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.launches()[-1]["args"][-1], FIRST)

    @unittest.skipUnless(shutil.which("tmux") and Path("/proc").is_dir(), "Linux and tmux required")
    def test_real_tmux_restart_preserves_same_directory_threads(self):
        plugin = Path.home() / ".tmux/plugins/tmux-resurrect/scripts"
        if not (plugin / "save.sh").exists():
            self.skipTest("tmux-resurrect is not installed")
        (self.base / ".dotfiles").symlink_to(ROOT, target_is_directory=True)
        self.thread(self.process(12), FIRST, header=False)
        self.thread(self.process(22), SECOND, header=False)
        native = self.bin / "native-agent"
        native.write_text('''import ctypes, fcntl, json, os, pathlib, sys, time
ctypes.CDLL(None).prctl(15, b"codex", 0, 0, 0)
sid = sys.argv[sys.argv.index("resume") + 1]
lock = open(pathlib.Path(os.environ["CODEX_HOME"]) / "thread-writer-locks" / (sid + ".lock"), "a")
fcntl.flock(lock, fcntl.LOCK_EX)
with open(os.environ["LAUNCH_LOG"], "a") as log:
    log.write(json.dumps({"program": "codex", "session_id": sid, "cwd": os.getcwd()}) + "\\n")
while True:
    time.sleep(1)
''')
        (self.bin / "codex").write_text(f"#!{sys.executable}\n" + '''import ctypes, os, pathlib, subprocess, sys
# Match the real Node launcher rather than presenting the wrapper as a native agent.
ctypes.CDLL(None).prctl(15, b"node", 0, 0, 0)
env = {**os.environ, "OCX_SHIM_ACTIVE_PID": str(os.getpid())}
sys.exit(subprocess.call([sys.executable, str(pathlib.Path(__file__).with_name("native-agent")),
                          *sys.argv[1:]], env=env))
''')
        socket = str(self.base / "tmux.sock")
        env = self.env.copy()
        env.pop("TMUX", None)
        env.pop("TMUX_PANE", None)

        def tmux(*args):
            return subprocess.check_output(["tmux", "-S", socket, *args], env=env,
                                           text=True, stderr=subprocess.PIPE)

        def cleanup():
            subprocess.run(["tmux", "-S", socket, "kill-server"], env=env,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        self.addCleanup(cleanup)
        snapshots = self.base / "resurrect"

        def configure():
            tmux("set", "-g", "default-shell", "/bin/sh")
            tmux("set", "-g", "@resurrect-dir", str(snapshots))
            for line in (ROOT / "tmux/tmux.conf").read_text().splitlines():
                if line.startswith(("set -g @resurrect-processes ", "set -g @resurrect-hook-post-save-layout ")):
                    tmux(*shlex.split(line))

        def wait_launches(count):
            deadline = time.monotonic() + 8
            while time.monotonic() < deadline:
                launches = [row for row in self.launches() if "session_id" in row]
                if len(launches) >= count:
                    return launches
                time.sleep(0.05)
            self.fail(f"expected {count} mock Codex launches")

        tmux("-f", "/dev/null", "new-session", "-d", "-s", "work", "-c", str(self.cwd),
             f"{shlex.quote(str(self.bin / 'codex'))} resume {FIRST}")
        configure()
        tmux("split-window", "-d", "-t", "work:0", "-c", str(self.cwd),
             f"{shlex.quote(str(self.bin / 'codex'))} resume {SECOND}")
        wait_launches(2)
        plugin_env = {**env, "TMUX": tmux("display-message", "-p", "#{socket_path},#{pid},0").strip()}
        result = subprocess.run(["bash", str(plugin / "save.sh"), "quiet"], env=plugin_env,
                                capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((snapshots / "last").read_text().count(":dotfiles-cx-resume "), 2)
        cleanup()
        tmux("-f", "/dev/null", "new-session", "-d", "-s", "seed", "/bin/sh")
        configure()
        plugin_env["TMUX"] = tmux("display-message", "-p", "#{socket_path},#{pid},0").strip()
        result = subprocess.run(["bash", str(plugin / "restore.sh"), "quiet"], env=plugin_env,
                                capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        restored = wait_launches(4)[2:]
        self.assertEqual({row["session_id"] for row in restored}, {FIRST, SECOND})
        self.assertTrue(all(row["cwd"] == str(self.cwd) for row in restored))
        self.assertEqual(sum(row["program"] == "ocx" for row in self.launches()), 2)


if __name__ == "__main__":
    unittest.main()
