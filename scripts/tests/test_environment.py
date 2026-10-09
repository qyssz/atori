"""Exercise read-only discovery against isolated temporary SDK layouts.

The fixture tools are empty files, never executable SDKs. A passing fixture
means discovery works, not that Flutter or Android builds have been tested.
Run with: python scripts/tests/test_environment.py
"""

from __future__ import annotations

import base64
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "check-environment.ps1"
POWERSHELL = shutil.which("pwsh") or shutil.which("powershell")


def quote_ps(value: object) -> str:
    return "'" + str(value).replace("'", "''") + "'"


@unittest.skipUnless(POWERSHELL, "PowerShell is required")
class EnvironmentDiscoveryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="atori-preflight-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.project = self.root / "project with spaces"
        self.project.mkdir()
        self.flutter = self.root / "flutter"
        self.android = self.root / "android"
        self.java = self.root / "java"
        self.git = self.root / "git"
        self.touch(self.git / "git.exe")

    @staticmethod
    def touch(path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"")

    def complete_layout(self) -> None:
        for relative in (
            "PROJECT_SPEC.md",
            "pubspec.yaml",
            "lib/main.dart",
            "android/app/src/main/AndroidManifest.xml",
        ):
            self.touch(self.project / relative)
        for relative in ("test", "assets/mock"):
            (self.project / relative).mkdir(parents=True)
        for relative in ("bin/flutter.bat", "bin/dart.bat"):
            self.touch(self.flutter / relative)
        for relative in ("bin/java.exe", "bin/javac.exe"):
            self.touch(self.java / relative)
        for relative in (
            "platform-tools/adb.exe",
            "platforms/android-35/android.jar",
            "build-tools/35.0.0/aapt2.exe",
            "build-tools/35.0.0/apksigner.bat",
            "cmdline-tools/latest/bin/sdkmanager.bat",
        ):
            self.touch(self.android / relative)

    def snapshot(self) -> dict[str, str]:
        return {
            str(path.relative_to(self.root)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in self.root.rglob("*")
            if path.is_file()
        }

    def inspect(self, *, project: Path | None = None, flutter: Path | None = None):
        command = (
            "[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false); "
            f"& {quote_ps(SCRIPT)} -Json "
            f"-ProjectRoot {quote_ps(project or self.project)} "
            f"-FlutterRoot {quote_ps(flutter or self.flutter)} "
            f"-AndroidSdkRoot {quote_ps(self.android)} "
            f"-JavaHome {quote_ps(self.java)}; exit $LASTEXITCODE"
        )
        encoded = base64.b64encode(command.encode("utf-16le")).decode("ascii")
        env = os.environ.copy()
        env["PATH"] = str(self.git) + os.pathsep + env.get("PATH", "")
        before = self.snapshot()
        result = subprocess.run(
            [POWERSHELL, "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-EncodedCommand", encoded],
            capture_output=True,
            encoding="utf-8",
            env=env,
            timeout=30,
            check=False,
        )
        self.assertEqual(result.stderr.strip(), "", result.stderr)
        self.assertEqual(self.snapshot(), before, "Preflight modified fixture files")
        return result.returncode, json.loads(result.stdout)

    def test_empty_project_reports_missing_prerequisites(self) -> None:
        code, report = self.inspect()
        self.assertEqual(code, 1)
        self.assertFalse(report["preflightPassed"])
        for missing in ("pubspec.yaml", "flutter", "dart", "android-sdk", "java", "javac"):
            self.assertIn(missing, report["missing"])

    def test_complete_layout_passes_discovery_without_running_tools(self) -> None:
        self.complete_layout()
        code, report = self.inspect()
        self.assertEqual(code, 0)
        self.assertTrue(report["preflightPassed"])
        self.assertEqual(report["missing"], [])
        self.assertTrue(any("versions" in warning for warning in report["warnings"]))

    def test_android_platform_below_minimum_is_rejected(self) -> None:
        self.complete_layout()
        (self.android / "platforms/android-35").rename(self.android / "platforms/android-34")
        code, report = self.inspect()
        self.assertEqual(code, 1)
        self.assertIn("android-platform", report["missing"])

    def test_incomplete_sdk_directory_is_rejected(self) -> None:
        self.complete_layout()
        (self.android / "platforms/android-35/android.jar").unlink()
        (self.android / "build-tools/35.0.0/apksigner.bat").unlink()
        code, report = self.inspect()
        self.assertEqual(code, 1)
        self.assertIn("android-platform", report["missing"])
        self.assertIn("android-build-tools", report["missing"])

    def test_explicit_invalid_flutter_root_does_not_fall_back(self) -> None:
        self.complete_layout()
        code, report = self.inspect(flutter=self.root / "missing-flutter")
        self.assertEqual(code, 1)
        self.assertIn("flutter", report["missing"])
        self.assertIn("dart", report["missing"])

    def test_invalid_project_returns_inspection_error(self) -> None:
        code, report = self.inspect(project=self.root / "does-not-exist")
        self.assertEqual(code, 2)
        self.assertIn("ProjectRoot", report["error"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
