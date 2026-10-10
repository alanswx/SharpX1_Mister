"""Asset-free reset orchestration checks; no MiSTer or native pixels are used."""
import base64
import contextlib
import hashlib
import io
import json
import pathlib
import shlex
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import zlib
import mister_reset_check as reset_check


def png(rgb):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0)) +
            chunk(b"IDAT", zlib.compress(b"\x00" + bytes(rgb))) + chunk(b"IEND", b""))


class ResetChecks(unittest.TestCase):
    def reject_cli(self, extra, message):
        result = subprocess.run([sys.executable, reset_check.__file__, "--manifest", "/nonexistent", *extra],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn(message, result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_repeat_bounds_fail_before_assets_or_ssh(self):
        for count in (0, -1, 9):
            self.reject_cli(["--repeat", str(count)], "repeat must be 1..8")

    def test_repeated_execution_requires_active_guard(self):
        self.reject_cli(["--repeat", "3", "--execute"], "repeated execution requires --expect-active")

    def run_case(self, repeat=1, execute=False, active="own-test", expected=None, wrong_pixels=False):
        with tempfile.TemporaryDirectory(prefix="x1-reset-orchestration-") as temporary:
            root = pathlib.Path(temporary)
            (root / "output_files").mkdir()
            title = png((255, 255, 255))
            played = png((255, 0, 0))
            (root / "title.png").write_bytes(title)
            media = "a" * 64 + "  /media/fat/games/SharpX1/HWTest/own/ipl.rom\n"
            prior = {"host": "mister126", "remote_rbf": "/media/fat/_Computer/own.rbf", "rbf_sha256": "b" * 64,
                     "tests": [{"title": "01_CROSS_Chase", "mgl": "/media/fat/_Computer/own.mgl",
                                "setname": "own-test", "initial_hashes": media, "final_hashes": media,
                                "screenshots": [{"label": "retained-assets-warm-reset", "file": "title.png",
                                                 "sha256": hashlib.sha256(title).hexdigest()}]}]}
            manifest = root / "prior.json"
            manifest.write_text(json.dumps(prior))
            commands = []
            screenshot = ""

            def remote(argv, **kwargs):
                nonlocal screenshot
                command = shlex.split(argv[-1])[-1]
                commands.append(command)
                if command == "cat /tmp/CORENAME":
                    answer = active
                elif command == "cat /tmp/CORENAME /tmp/RBFNAME":
                    answer = active + "SharpX1"
                elif command.startswith("sha256sum "):
                    if "own.rbf" in command:
                        answer = "b" * 64 + "  core\n"
                    elif reset_check.HELPER in command:
                        answer = hashlib.sha256(pathlib.Path(reset_check.__file__).with_name("mister_uinput.py").read_bytes()).hexdigest() + "  helper\n"
                    else:
                        answer = media
                elif "screenshot " in command and "/dev/MiSTer_cmd" in command:
                    screenshot = command
                    answer = ""
                elif command.startswith("python3 -c "):
                    is_title = "-after.png" in screenshot and not wrong_pixels
                    answer = base64.b64encode(title if is_title else played).decode()
                else:
                    answer = ""
                return subprocess.CompletedProcess(argv, 0, answer, "")

            arguments = ["mister_reset_check.py", "--manifest", str(manifest), "--repeat", str(repeat)]
            if execute:
                arguments.append("--execute")
            if expected:
                arguments += ["--expect-active", expected]
            with mock.patch.object(sys, "argv", arguments), mock.patch.object(reset_check, "ROOT", root), \
                    mock.patch.object(reset_check.subprocess, "run", side_effect=remote), \
                    mock.patch.object(reset_check.time, "sleep"), contextlib.redirect_stdout(io.StringIO()):
                if expected and active != expected:
                    with self.assertRaisesRegex(AssertionError, "Active set changed"):
                        reset_check.main()
                elif wrong_pixels:
                    with self.assertRaisesRegex(AssertionError, "did not return"):
                        reset_check.main()
                else:
                    reset_check.main()
            written = list((root / "output_files").glob("*/manifest.json"))
            evidence = json.loads(written[0].read_text()) if written else None
            return commands, evidence

    def test_preflight_never_sends_commands(self):
        commands, evidence = self.run_case()
        self.assertIsNone(evidence)
        self.assertFalse(any("/dev/MiSTer_cmd" in c for c in commands))

    def test_three_rounds_have_one_initial_load(self):
        commands, evidence = self.run_case(3, True, expected="own-test")
        self.assertEqual(sum("load_core " in c for c in commands), 1)
        self.assertEqual(len(evidence["tests"]), 6)
        self.assertEqual([t["iteration"] for t in evidence["tests"]], [1, 1, 2, 2, 3, 3])
        images = [t[field] for t in evidence["tests"] for field in ("before_png", "after_png", "input_png")]
        self.assertEqual(len(set(images)), 18)
        self.assertTrue(all(t["matches_native_title"] and t["input_changes_title"] and t["unchanged_media"] for t in evidence["tests"]))

    def test_changed_active_core_stops_before_load(self):
        commands, evidence = self.run_case(3, True, active="someone-else", expected="own-test")
        self.assertIsNone(evidence)
        self.assertFalse(any("/dev/MiSTer_cmd" in c for c in commands))

    def test_bad_reset_pixels_are_retained_not_accepted(self):
        _, evidence = self.run_case(3, True, expected="own-test", wrong_pixels=True)
        self.assertEqual(len(evidence["tests"]), 1)
        self.assertFalse(evidence["tests"][0]["matches_native_title"])
        self.assertNotIn("unchanged_media", evidence["tests"][0])


if __name__ == "__main__":
    unittest.main()
