"""Collector contract checks with synthetic subprocess outputs, not machine tests."""
import contextlib
import hashlib
import io
import json
import pathlib
import tempfile
import unittest
from unittest.mock import patch

import probe_special_titles as probe


class ObservationContract(unittest.TestCase):
    def collect(self, turbo, fault=None):
        with tempfile.TemporaryDirectory(prefix="x1-probe-contract-") as directory:
            root = pathlib.Path(directory)
            for name in ("runner", "rom", "keys", "disk"):
                (root / name).write_bytes(b"synthetic collector input")
            manifest = root / "manifest.json"
            manifest.write_text(json.dumps({"games": [{"slug": "arcus", "files": [{
                "native_candidate": True, "member": "Disk 1", "path": "disk",
                "sha256": hashlib.sha256((root / "disk").read_bytes()).hexdigest()}]}]}))
            argv = ["probe", str(root / "runner"), "arcus", "--manifest", str(manifest),
                    "--rom", str(root / "rom"), "--keys", str(root / "keys"),
                    "--seconds", "1", "--output", str(root / "output"),
                    "--video-observations"]

            def run(command, **kwargs):
                self.assertIn("--video-dump", command)
                prefix = pathlib.Path(command[command.index("--dump") + 1])
                self.assertEqual(command[command.index("--video-dump") + 1], str(prefix))
                suffixes = (".ram", ".text", ".attr", ".subram", ".cpu", ".ppm",
                            ".gram-b", ".gram-r", ".gram-g", ".pcg-b", ".pcg-r", ".pcg-g",
                            ".video-palette", ".video-samples", ".crtc", ".cpu-fetches")
                if turbo:
                    suffixes += (".video-controls", ".ctc")
                for suffix in suffixes:
                    if fault == "missing" and suffix == ".cpu-fetches":
                        continue
                    data = b"synthetic observation"
                    if fault == "changed" and prefix.name == "repeat" and suffix == ".ctc":
                        data += b"changed"
                    pathlib.Path(str(prefix) + suffix).write_bytes(data)
                report = {"disk_writes": 0, "turbo_foundation": turbo}
                return probe.subprocess.CompletedProcess(command, 0, json.dumps(report), "")

            with patch("sys.argv", argv), patch.object(probe.subprocess, "run", run), \
                    contextlib.redirect_stdout(io.StringIO()):
                probe.main()
            evidence = json.loads((root / "output/evidence.json").read_text())
            self.assertTrue(evidence["repeatable"])
            self.assertTrue(evidence["video_observations"])
            self.assertFalse(evidence["gameplay_verified"])
            self.assertEqual(".ctc" in evidence["runs"][0]["artifacts"], turbo)

    def test_base(self):
        self.collect(False)

    def test_turbo(self):
        self.collect(True)

    def test_missing_observation_rejected(self):
        with self.assertRaises(FileNotFoundError):
            self.collect(True, "missing")

    def test_changed_turbo_observation_rejected(self):
        with self.assertRaisesRegex(SystemExit, "FAIL"):
            self.collect(True, "changed")


if __name__ == "__main__":
    unittest.main()
