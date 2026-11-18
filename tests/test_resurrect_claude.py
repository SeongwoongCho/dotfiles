"""Verify exact session selection and ocx launch without starting real agents."""

import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tmux"))
SCRIPT = ROOT / "tmux/resurrect-claude"
LOADER = importlib.machinery.SourceFileLoader("resurrect_claude", str(SCRIPT))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
RESTORE = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(RESTORE)
FIRST = "11111111-1111-4111-8111-111111111111"
SECOND = "22222222-2222-4222-8222-222222222222"


def pane(index, command="claude", full="claude --continue"):
    return "\t".join(["pane", "work", "1", "1", ":*", str(index), "title",
                      ":/same/project", "1", command, ":" + full]) + "\n"


class ClaudeRestoreTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.config = self.base / "claude config"
        (self.config / "sessions").mkdir(parents=True)
        self.proc = self.base / "proc"
        self.proc.mkdir()
        self.cwd = self.base / "project [1m] & 'quoted' $(touch INJECTED)"
        self.cwd.mkdir()
        self.log = self.base / "launch.json"
        self.bin = self.base / "bin"
        self.bin.mkdir()
        ocx = self.bin / "ocx"
        ocx.write_text(f"#!{sys.executable}\n" + '''import json, os, pathlib, sys
pathlib.Path(os.environ["LAUNCH_LOG"]).write_text(json.dumps({
    "args": sys.argv[1:], "cwd": os.getcwd(),
    "env": {k: os.environ.get(k) for k in (
        "IS_SANDBOX", "CLAUDE_CONFIG_DIR", "CLAUDE_CODE_TMPDIR")},
}))
sys.exit(int(os.environ.get("OCX_EXIT", "0")))
''')
        ocx.chmod(0o755)
        self.env = os.environ.copy()
        for key in RESTORE.SESSION_ENV:
            self.env.pop(key, None)
        self.env.update(HOME=str(self.base), PATH=f"{self.bin}:{os.environ['PATH']}",
                        LAUNCH_LOG=str(self.log))

    def record(self, session_id=FIRST):
        return {"session_id": session_id, "cwd": str(self.cwd),
                "config_dir": str(self.config), "tmpdir": str(self.cwd / "tmp [1m]")}

    def register(self, pid, session_id=FIRST, start="123", foreground=True):
        record = {"pid": pid, "sessionId": session_id, "cwd": str(self.cwd),
                  "procStart": start, "kind": "interactive"}
        (self.config / "sessions" / f"{pid}.json").write_text(json.dumps(record))
        process = self.proc / str(pid)
        process.mkdir(exist_ok=True)
        stat = ["0"] * 20
        stat[0], stat[2], stat[5], stat[19] = "S", "100", "100" if foreground else "200", "123"
        (process / "stat").write_text(f"{pid} (claude (test)) " + " ".join(stat))
        (process / "environ").write_bytes(
            f"CLAUDE_CONFIG_DIR={self.config}\0CLAUDE_CODE_TMPDIR={self.cwd / 'tmp [1m]'}\0"
            "ANTHROPIC_AUTH_TOKEN=must-not-be-saved\0".encode())

    def launch(self, record=None, args=None, env=None):
        if args is None:
            args = ["--restore", json.dumps(record or self.record()).encode().hex()]
        return subprocess.run([str(SCRIPT), *args], cwd=self.cwd,
                              env=env or self.env, capture_output=True, text=True)

    def test_registry_identity_foreground_and_environment(self):
        self.register(11)
        self.assertEqual(RESTORE.session_record(11, self.proc), self.record())
        self.register(11, start="stale-pid")
        self.assertIsNone(RESTORE.session_record(11, self.proc))
        self.register(11, foreground=False)
        self.assertIsNone(RESTORE.session_record(11, self.proc))
        self.assertIsNone(RESTORE.session_record(99, self.proc))

    def test_bad_registry_is_ignored(self):
        self.register(11)
        registry = self.config / "sessions/11.json"
        for content in ("{", "[]", "null", '{"sessionId":"bad"}'):
            with self.subTest(content=content):
                registry.write_text(content)
                self.assertIsNone(RESTORE.session_record(11, self.proc))

    def test_wrappers_and_subagents_and_ambiguity(self):
        records = {12: self.record(), 13: self.record(SECOND)}
        with mock.patch.object(RESTORE, "session_record", side_effect=records.get):
            self.assertEqual(RESTORE.pane_session(10, {10: [11], 11: [12], 12: [13]}),
                             self.record())
            self.assertIsNone(RESTORE.pane_session(10, {10: [12, 13]}))
            self.assertIsNone(RESTORE.pane_session(10, {10: [11], 11: [10]}))

    def test_snapshot_keeps_same_cwd_sessions_distinct_and_old_saves_independent(self):
        self.register(12, FIRST)
        self.register(22, SECOND)
        snapshot = self.base / "snapshot.txt"
        untouched = pane(3, "nvim", "nvim main.py") + "window\twork\t1\t:editor\n"
        original = pane(1) + pane(2, "node", "node ocx claude --model opus[1m]") + untouched
        snapshot.write_text(original)
        reader = RESTORE.session_record
        outputs = ["10 1 zsh\n11 10 node\n12 11 claude\n20 1 zsh\n22 20 claude\n30 1 nvim\n",
                   "work\t1\t1\t10\nwork\t1\t2\t20\nwork\t1\t3\t30\n"]
        with mock.patch.object(RESTORE.subprocess, "check_output", side_effect=outputs), \
                mock.patch.object(RESTORE, "session_record", side_effect=lambda pid: reader(pid, self.proc)):
            RESTORE.save(snapshot)
        saved = snapshot.read_text()
        self.assertTrue(saved.endswith(untouched))
        self.assertNotIn("must-not-be-saved", saved)
        for line, session_id in zip(saved.splitlines(), (FIRST, SECOND)):
            command, payload = line.split("\t")[10][1:].split()
            self.assertEqual(command, RESTORE.MARKER)
            self.assertEqual(json.loads(bytes.fromhex(payload))["session_id"], session_id)
        older = self.base / "older.txt"
        older.write_text(saved)
        self.register(12, SECOND)  # /clear or /resume in the same live process
        snapshot.write_text(original)
        with mock.patch.object(RESTORE.subprocess, "check_output", side_effect=outputs), \
                mock.patch.object(RESTORE, "session_record", side_effect=lambda pid: reader(pid, self.proc)):
            RESTORE.save(snapshot)
        self.assertNotEqual(snapshot.read_text(), saved)
        self.assertEqual(older.read_text(), saved)

    def test_exact_restore_uses_ocx_and_preserves_paths_without_model_override(self):
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        launch = json.loads(self.log.read_text())
        self.assertEqual(launch["args"], ["claude", "--resume", FIRST,
                                          "--dangerously-skip-permissions"])
        self.assertEqual(launch["cwd"], str(self.cwd))
        self.assertEqual(launch["env"], {"IS_SANDBOX": "1", "CLAUDE_CONFIG_DIR": str(self.config),
                                          "CLAUDE_CODE_TMPDIR": self.record()["tmpdir"]})
        self.assertFalse((self.cwd / "INJECTED").exists())

    def test_legacy_save_opens_picker_instead_of_latest_or_new_conversation(self):
        result = self.launch(args=[])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("choose the conversation", result.stderr)
        launch = json.loads(self.log.read_text())
        self.assertEqual(launch["args"], ["claude", "--resume", "--dangerously-skip-permissions"])
        self.assertEqual(launch["env"]["CLAUDE_CODE_TMPDIR"], str(self.cwd / "claude-tmp"))

    def test_bad_payload_or_missing_cwd_does_not_start_a_different_session(self):
        invalid = self.record()
        invalid["cwd"] = str(self.base / "missing")
        for args in (["--restore", "invalid"], ["--restore", "6e756c6c"],
                     ["--restore", json.dumps(invalid).encode().hex()]):
            with self.subTest(args=args):
                result = self.launch(args=args)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.log.exists())

    def test_proxy_failure_is_returned_without_native_fallback(self):
        result = self.launch(env={**self.env, "OCX_EXIT": "23"})
        self.assertEqual(result.returncode, 23)

    @unittest.skipUnless(shutil.which("zsh"), "zsh is not installed")
    def test_installed_resurrect_mapping_is_safe_in_zsh(self):
        plugin = Path.home() / ".tmux/plugins/tmux-resurrect/scripts"
        if not (plugin / "process_restore_helpers.sh").is_file():
            self.skipTest("tmux-resurrect is not installed")
        options = next(line for line in (ROOT / "tmux/tmux.conf").read_text().splitlines()
                       if line.startswith("set -g @resurrect-processes "))
        restore_list = shlex.split(options)[3]
        payload = json.dumps(self.record()).encode().hex()
        # Exercise upstream's real sed-based argument expansion, then zsh parsing.
        script = '''source "$1/variables.sh"
source "$1/helpers.sh"
source "$1/process_restore_helpers.sh"
get_tmux_option() { [[ "$1" == "@resurrect-processes" ]] && echo "$RESTORE_LIST"; }
_get_inline_strategy "$SAVED_COMMAND"
'''
        env = {**self.env, "RESTORE_LIST": restore_list,
               "SAVED_COMMAND": f"{RESTORE.MARKER} {payload}"}
        result = subprocess.run(["bash", "-c", script, "bash", str(plugin)],
                                env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), f"~/.dotfiles/tmux/resurrect-claude --restore {payload}")
        command = result.stdout.strip().replace("~/.dotfiles/tmux/resurrect-claude", shlex.quote(str(SCRIPT)), 1)
        result = subprocess.run(["zsh", "-f", "-c", command], env=self.env,
                                cwd=self.cwd, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.log.read_text())["args"][2], FIRST)

    @unittest.skipUnless(shutil.which("tmux") and Path("/proc").is_dir(),
                         "Linux and tmux are required")
    def test_real_tmux_save_and_restore_through_ocx_wrapper(self):
        plugin = Path.home() / ".tmux/plugins/tmux-resurrect/scripts"
        if not (plugin / "save.sh").is_file():
            self.skipTest("tmux-resurrect is not installed")
        (self.base / ".dotfiles").symlink_to(ROOT, target_is_directory=True)
        # A wrapper parent and interactive child, like the real ocx launcher.
        (self.bin / "ocx").write_text(f"#!{sys.executable}\n" + '''import os, subprocess, sys
sys.exit(subprocess.call([os.path.join(os.path.dirname(__file__), "claude"), *sys.argv[2:]]))
''')
        agent = self.bin / "claude"
        agent.write_text(f"#!{sys.executable}\n" + '''import json, os, pathlib, sys, time
pid = os.getpid()
sid = sys.argv[sys.argv.index("--resume") + 1]
root = pathlib.Path(os.environ["CLAUDE_CONFIG_DIR"])
stat = pathlib.Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
(root / "sessions" / f"{pid}.json").write_text(json.dumps({
    "pid": pid, "sessionId": sid, "cwd": os.getcwd(),
    "procStart": stat[19], "kind": "interactive",
}))
with open(os.environ["LAUNCH_LOG"], "a") as log:
    log.write(json.dumps({"session_id": sid, "cwd": os.getcwd(), "args": sys.argv[1:]}) + "\\n")
while True:
    time.sleep(1)
''')
        agent.chmod(0o755)
        socket = str(self.base / "tmux.sock")
        env = {**self.env, "CLAUDE_CONFIG_DIR": str(self.config)}
        env.pop("TMUX", None)
        env.pop("TMUX_PANE", None)
        snapshots = self.base / "resurrect"
        options = [shlex.split(line) for line in (ROOT / "tmux/tmux.conf").read_text().splitlines()
                   if line.startswith(("set -g @resurrect-processes ",
                                       "set -g @resurrect-hook-post-save-layout "))]

        def tmux(*args):
            return subprocess.check_output(["tmux", "-S", socket, *args], env=env,
                                           text=True, stderr=subprocess.PIPE)

        def cleanup():
            subprocess.run(["tmux", "-S", socket, "kill-server"], env=env,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        self.addCleanup(cleanup)

        def configure():
            tmux("set", "-g", "default-shell", "/bin/sh")
            tmux("set", "-g", "@resurrect-dir", str(snapshots))
            for option in options:
                tmux(*option)

        def wait_launches(count):
            deadline = time.monotonic() + 8
            while time.monotonic() < deadline:
                if self.log.exists():
                    lines = self.log.read_text().splitlines()
                    if len(lines) >= count:
                        return [json.loads(line) for line in lines]
                time.sleep(0.05)
            self.fail(f"expected {count} fake Claude launches")

        tmux("-f", "/dev/null", "new-session", "-d", "-s", "work", "-c", str(self.cwd),
             f"{shlex.quote(str(self.bin / 'ocx'))} claude --resume {FIRST}")
        configure()
        tmux("split-window", "-d", "-t", "work:0", "-c", str(self.cwd),
             f"{shlex.quote(str(self.bin / 'ocx'))} claude --resume {SECOND}")
        wait_launches(2)
        plugin_env = {**env, "TMUX": tmux("display-message", "-p", "#{socket_path},#{pid},0").strip()}
        result = subprocess.run(["bash", str(plugin / "save.sh"), "quiet"], env=plugin_env,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        saved = (snapshots / "last").read_text()
        self.assertEqual(saved.count(":dotfiles-cc-resume "), 2)
        cleanup()
        # A fresh server is the container-restart case; no live pane can help it.
        tmux("-f", "/dev/null", "new-session", "-d", "-s", "seed", "/bin/sh")
        configure()
        plugin_env["TMUX"] = tmux("display-message", "-p", "#{socket_path},#{pid},0").strip()
        result = subprocess.run(["bash", str(plugin / "restore.sh"), "quiet"], env=plugin_env,
                                capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        restored = wait_launches(4)[2:]
        self.assertEqual({row["session_id"] for row in restored}, {FIRST, SECOND})
        self.assertTrue(all(row["cwd"] == str(self.cwd) for row in restored))
        self.assertTrue(all("--dangerously-skip-permissions" in row["args"] for row in restored))


if __name__ == "__main__":
    unittest.main()
