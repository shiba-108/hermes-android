#!/usr/bin/env python3
"""Isolated regression checks for the Android no-root installer and Web UI."""

import importlib.util
import json
import os
from pathlib import Path
import shlex
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time
import types
import unittest
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "web" / "server.py"
WEBUI = ROOT / "scripts" / "webui.sh"
INSTALLER = ROOT / "install.sh"


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def write_executable(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    path.chmod(0o755)


def request_json(url, payload):
    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=4) as response:
        return json.loads(response.read().decode("utf-8"))


class NoRootHarness(unittest.TestCase):
    def test_shell_syntax(self):
        shell_files = [INSTALLER]
        shell_files += sorted((ROOT / "scripts").glob("*.sh"))
        shell_files += sorted((ROOT / "service.d").glob("*.sh"))
        for path in shell_files:
            with self.subTest(path=str(path.relative_to(ROOT))):
                result = subprocess.run(
                    ["sh", "-n", str(path)], text=True, capture_output=True
                )
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_server_python_syntax(self):
        compile(SERVER.read_text(encoding="utf-8"), str(SERVER), "exec")

    def test_preflight_lock_name_payload_is_not_executed(self):
        with tempfile.TemporaryDirectory(prefix="hermes-lock-payload-") as temp_name:
            temp = Path(temp_name)
            hm = temp / "home" / ".hermes-home"
            venv = temp / "venv"
            fake_site = temp / "pythonpath"
            package = "harness-probe"
            dist_info = fake_site / "harness_probe-0.0.1.dist-info"
            dist_info.mkdir(parents=True)
            (dist_info / "METADATA").write_text(
                "Metadata-Version: 2.1\nName: harness-probe\nVersion: 0.0.1\n",
                encoding="utf-8",
            )

            marker = temp / "payload-ran"
            payload_name = (
                f"{package}')!='__never__' and "
                f"(__import__('pathlib').Path({str(marker)!r}).touch() is None) and "
                f"('{package}"
            )
            lock = temp / "payload.lock"
            lock.write_text(f"{payload_name}==999\n", encoding="utf-8")
            write_executable(
                venv / "bin" / "python",
                "#!/bin/sh\n"
                'if [ "${1:-}" = "-m" ] && [ "${2:-}" = "pip" ]; then exit 0; fi\n'
                f"exec {shlex.quote(sys.executable)} \"$@\"\n",
            )

            env = os.environ.copy()
            env.update(
                {
                    "HERMES_HOME": str(hm),
                    "HERMES_VENV": str(venv),
                    "HERMES_LOCK": str(lock),
                    "PYTHONPATH": os.pathsep.join(
                        part for part in (str(fake_site), env.get("PYTHONPATH", "")) if part
                    ),
                }
            )
            result = subprocess.run(
                ["/bin/sh", str(ROOT / "scripts" / "preflight_venv.sh")],
                cwd=ROOT,
                env=env,
                text=True,
                capture_output=True,
                timeout=10,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertFalse(marker.exists(), "lock package name executed Python code")

    def test_root_preflight_fails_closed_for_untrusted_lock_path(self):
        with tempfile.TemporaryDirectory(prefix="hermes-root-lock-") as temp_name:
            temp = Path(temp_name)
            fake_bin = temp / "bin"
            fake_bin.mkdir()
            real_id = shutil.which("id")
            self.assertIsNotNone(real_id)
            write_executable(
                fake_bin / "id",
                "#!/bin/sh\n"
                'if [ "${1:-}" = "-u" ]; then echo 0; else '
                f"exec {shlex.quote(real_id)} \"$@\"; fi\n",
            )

            hm = temp / "home" / ".hermes-home"
            lock = hm / "backups" / "venv-requirements.lock"
            lock.parent.mkdir(parents=True)
            lock.write_text("harness-probe==0.0.1\n", encoding="utf-8")
            venv = temp / "venv"
            write_executable(
                venv / "bin" / "python",
                f"#!/bin/sh\nexec {shlex.quote(sys.executable)} \"$@\"\n",
            )

            env = os.environ.copy()
            env.update(
                {
                    "PATH": str(fake_bin) + os.pathsep + env.get("PATH", ""),
                    "HOME": str(temp / "home"),
                    "HERMES_HOME": str(hm),
                    "HERMES_VENV": str(venv),
                }
            )
            env.pop("HERMES_LOCK", None)
            result = subprocess.run(
                ["/bin/sh", str(ROOT / "scripts" / "preflight_venv.sh")],
                cwd=ROOT,
                env=env,
                text=True,
                capture_output=True,
                timeout=10,
            )
            output = result.stdout + result.stderr
            self.assertNotEqual(result.returncode, 0, output)
            self.assertIn("LOCK TRUST FAILURE", output)
            self.assertNotIn("preflight done", (hm / "logs" / "preflight.log").read_text())

    def test_host_default_preserves_root_and_loopback_for_nonroot(self):
        module = types.ModuleType("hermes_server_harness")
        module.__file__ = str(SERVER)
        code = compile(SERVER.read_text(encoding="utf-8"), str(SERVER), "exec")
        exec(code, module.__dict__)

        original_geteuid = module.os.geteuid
        try:
            module.os.geteuid = lambda: 1000
            self.assertEqual(module.default_host(), "127.0.0.1")
            module.os.geteuid = lambda: 0
            self.assertEqual(module.default_host(), "0.0.0.0")
        finally:
            module.os.geteuid = original_geteuid

    def test_webui_launcher_and_api_use_custom_venv(self):
        with tempfile.TemporaryDirectory(prefix="hermes-webui-test-") as temp_name:
            temp = Path(temp_name)
            home = temp / "home"
            hm = home / ".hermes-home"
            web_copy = hm / "web" / "server.py"
            web_copy.parent.mkdir(parents=True)
            shutil.copy2(SERVER, web_copy)

            custom_venv = temp / "custom-venv"
            default_venv = home / "hermes-venv"
            custom_marker = temp / "custom-hermes-called"
            default_marker = temp / "default-hermes-called"
            python_marker = temp / "custom-python-called"

            write_executable(
                custom_venv / "bin" / "python",
                "#!/bin/sh\n"
                'printf "used\\n" >> "$PYTHON_MARKER"\n'
                f"exec {shlex.quote(sys.executable)} \"$@\"\n",
            )
            write_executable(
                custom_venv / "bin" / "hermes",
                "#!/bin/sh\n"
                'printf "called\\n" > "$CUSTOM_HERMES_MARKER"\n'
                "printf 'custom-venv-reply\\n'\n",
            )
            write_executable(
                default_venv / "bin" / "hermes",
                "#!/bin/sh\n"
                'printf "called\\n" > "$DEFAULT_HERMES_MARKER"\n'
                "printf 'default-venv-reply\\n'\n",
            )

            port = free_port()
            env = os.environ.copy()
            env.update(
                {
                    "HOME": str(home),
                    "HERMES_HOME": str(hm),
                    "HERMES_VENV": str(custom_venv),
                    "WEBUI_PORT": str(port),
                    "CUSTOM_HERMES_MARKER": str(custom_marker),
                    "DEFAULT_HERMES_MARKER": str(default_marker),
                    "PYTHON_MARKER": str(python_marker),
                }
            )
            env.pop("WEBUI_HOST", None)
            # On a root-run CI host, explicitly constrain this integration test;
            # the root/non-root defaults themselves are tested above.
            if os.geteuid() == 0:
                env["WEBUI_HOST"] = "127.0.0.1"

            base = f"http://127.0.0.1:{port}"
            try:
                start = subprocess.run(
                    ["sh", str(WEBUI), "start"],
                    cwd=ROOT,
                    env=env,
                    text=True,
                    capture_output=True,
                    timeout=12,
                )
                self.assertEqual(start.returncode, 0, start.stdout + start.stderr)
                self.assertIn(f"127.0.0.1:{port}", start.stdout)

                with urllib.request.urlopen(base + "/", timeout=4) as response:
                    self.assertEqual(response.status, 200)
                    self.assertIn("Hermes", response.read().decode("utf-8"))

                result = request_json(base + "/api/send", {"message": "harness probe"})
                self.assertEqual(result.get("reply"), "custom-venv-reply")
                self.assertTrue(custom_marker.exists(), "custom Hermes stub was not called")
                self.assertFalse(default_marker.exists(), "default Hermes stub was called")
                self.assertTrue(python_marker.exists(), "custom venv Python was not used")

                status = subprocess.run(
                    ["sh", str(WEBUI), "status"],
                    cwd=ROOT,
                    env=env,
                    text=True,
                    capture_output=True,
                    timeout=6,
                )
                self.assertEqual(status.returncode, 0, status.stdout + status.stderr)
                self.assertIn(f"host 127.0.0.1 port {port}", status.stdout)
            finally:
                subprocess.run(
                    ["sh", str(WEBUI), "stop"],
                    cwd=ROOT,
                    env=env,
                    text=True,
                    capture_output=True,
                    timeout=8,
                )
                pid_file = hm / "webui.pid"
                if pid_file.exists():
                    try:
                        pid = int(pid_file.read_text(encoding="utf-8").strip())
                        cmdline = Path(f"/proc/{pid}/cmdline").read_bytes().replace(b"\0", b" ")
                        if str(web_copy).encode() in cmdline:
                            os.kill(pid, signal.SIGTERM)
                    except (OSError, ValueError, ProcessLookupError):
                        pass
                deadline = time.monotonic() + 2
                while time.monotonic() < deadline:
                    try:
                        urllib.request.urlopen(base + "/", timeout=0.2).close()
                        time.sleep(0.05)
                    except (urllib.error.URLError, TimeoutError, OSError):
                        break

    def test_installer_fails_without_python_before_writing_files(self):
        with tempfile.TemporaryDirectory(prefix="hermes-no-python-") as temp_name:
            temp = Path(temp_name)
            home = temp / "home"
            hm = home / ".hermes-home"
            env = {
                "PATH": str(temp / "empty-path"),
                "HOME": str(home),
                "HERMES_HOME": str(hm),
                "HERMES_AGENT_DIR": str(temp / "hermes-agent"),
                "HERMES_VENV": str(temp / "hermes-venv"),
                "REPO_DIR": str(ROOT),
            }
            result = subprocess.run(
                ["/bin/sh", str(INSTALLER)],
                cwd=ROOT,
                env=env,
                text=True,
                capture_output=True,
                timeout=8,
            )
            output = result.stdout + result.stderr
            self.assertNotEqual(result.returncode, 0, output)
            self.assertIn("Python", output)
            self.assertNotIn("Xong.", output)
            self.assertFalse(hm.exists(), "installer wrote files before prerequisite failure")

    def test_installer_fails_without_git_when_agent_clone_is_required(self):
        with tempfile.TemporaryDirectory(prefix="hermes-no-git-") as temp_name:
            temp = Path(temp_name)
            home = temp / "home"
            hm = home / ".hermes-home"
            only_python = temp / "path"
            only_python.mkdir()
            (only_python / "python3").symlink_to(sys.executable)
            env = {
                "PATH": str(only_python),
                "HOME": str(home),
                "HERMES_HOME": str(hm),
                "HERMES_AGENT_DIR": str(temp / "hermes-agent-not-installed"),
                "HERMES_VENV": str(temp / "hermes-venv"),
                "REPO_DIR": str(ROOT),
            }
            result = subprocess.run(
                ["/bin/sh", str(INSTALLER)],
                cwd=ROOT,
                env=env,
                text=True,
                capture_output=True,
                timeout=8,
            )
            output = result.stdout + result.stderr
            self.assertNotEqual(result.returncode, 0, output)
            self.assertIn("git", output)
            self.assertNotIn("Xong.", output)
            self.assertFalse(hm.exists(), "installer wrote files before prerequisite failure")


if __name__ == "__main__":
    unittest.main(verbosity=2)
