"""Exercise the tmux installer with download/build/install commands mocked."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
HARNESS = r'''
source "$MYDOTFILES/src/install-prerequisite.sh"
VERSION_TMUX="$TEST_VERSION"
mktemp() { printf '%s\n' "$TEST_BUILD_DIR"; }
nproc() { echo 2; }
curl() {
    echo "download $*" >> "$TEST_LOG"
    [[ "$TEST_FAIL" != download ]]
}
tar() {
    echo extract >> "$TEST_LOG"
    [[ "$TEST_FAIL" != extract ]] || return 1
    mkdir "tmux-$VERSION_TMUX"
    cat > "tmux-$VERSION_TMUX/configure" <<'CONFIGURE'
#!/bin/bash
echo "configure $*" >> "$TEST_LOG"
[[ "$TEST_FAIL" != configure ]]
CONFIGURE
    chmod +x "tmux-$VERSION_TMUX/configure"
}
make() {
    local stage=build
    [[ "$1" == install ]] && stage=install
    echo "$stage $*" >> "$TEST_LOG"
    [[ "$TEST_FAIL" != "$stage" ]]
}
# Any unexpected attempt to touch a real server is a test failure.
tmux() { echo unexpected-tmux >> "$TEST_LOG"; return 99; }
install_tmux
result=$?
echo "failures=${#FAILED_PACKAGES[@]}"
exit "$result"
'''


class TmuxInstallTests(unittest.TestCase):
    def run_installer(self, fail="", version="3.7c"):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            build = base / "build"
            build.mkdir()
            log = base / "commands"
            env = os.environ.copy()
            env.pop("SUDO_USER", None)
            env.update(
                MYDOTFILES=str(ROOT), TEST_VERSION=version, TEST_FAIL=fail,
                TEST_BUILD_DIR=str(build), TEST_LOG=str(log),
            )
            result = subprocess.run(
                ["bash", "-c", HARNESS], env=env,
                capture_output=True, text=True, check=False,
            )
            lines = log.read_text().splitlines() if log.exists() else []
            if version != "latest":
                self.assertFalse(build.exists(), "build directory was not cleaned up")
            return result, lines

    def test_pinned_sixel_build(self):
        config = (ROOT / "config/versions.sh").read_text()
        self.assertIn('export VERSION_TMUX="${VERSION_TMUX:-3.7c}"', config)
        result, lines = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("failures=0", result.stdout)
        self.assertEqual([line.split()[0] for line in lines],
                         ["download", "extract", "configure", "build", "install"])
        self.assertIn("https://github.com/tmux/tmux/releases/download/3.7c/tmux-3.7c.tar.gz", lines[0])
        self.assertEqual(lines[2], "configure --prefix=/usr/local --enable-sixel")
        self.assertEqual(lines[3:], ["build -j2", "install install"])

    def test_failure_stops_pipeline_and_is_reported(self):
        stages = ["download", "extract", "configure", "build", "install"]
        for index, stage in enumerate(stages):
            with self.subTest(stage=stage):
                result, lines = self.run_installer(fail=stage)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("failures=1", result.stdout)
                self.assertEqual([line.split()[0] for line in lines], stages[:index + 1])

    def test_latest_is_rejected_before_download(self):
        result, lines = self.run_installer(version="latest")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("failures=1", result.stdout)
        self.assertEqual(lines, [])


if __name__ == "__main__":
    unittest.main()
