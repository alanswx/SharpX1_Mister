"""Asset-free native continuation safety checks; no emulator is executed."""
import contextlib
import io
import json
import pathlib
import subprocess
import sys
import tempfile
from unittest import mock
import continue_native_probe as probe


with tempfile.TemporaryDirectory(prefix="x1-native-continuation-") as directory:
    root = pathlib.Path(directory)
    runner, disk, state, keys = (root / n for n in ("Vtop", "disk.d88", "cold.state", "start.keys"))
    for path in (runner, disk, state):
        path.write_bytes(b"synthetic-not-emulated-" + path.name.encode())
    keys.write_text("50 1a\n1050 f0\n1052 1a\n")
    evidence_path = root / "evidence.json"
    evidence = {"repeatable": True, "unchanged_inputs": True,
                "inputs_sha256": {str(disk): probe.sha(disk)},
                "executable_sha256": probe.sha(runner),
                "cycles_reference_hz": 32000000, "duration_seconds": 4,
                "runs": [{"command": [str(runner), "--disk", str(disk), "--save-state", str(state)],
                          "artifacts": {".state": probe.sha(state)}}]}
    evidence_path.write_text(json.dumps(evidence))
    calls = []
    elapsed = 4000
    def fake_run(command, **kwargs):
        global elapsed
        calls.append(command)
        elapsed += int(command[command.index("--cycles") + 1]) // 32000
        pathlib.Path(command[command.index("--save-state") + 1]).write_bytes(b"synthetic-continuation")
        return subprocess.CompletedProcess(command, 0, json.dumps({
            "disk_writes": 0, "time_ps": elapsed * 1000000000, "frame_hash": "synthetic"}) + "\n", "")
    argv = ["continue", str(evidence_path), "--output", str(root / "good"),
            "--chunks-ms", "4000", "4000", "--final-keys", str(keys)]
    with mock.patch.object(sys, "argv", argv), mock.patch.object(subprocess, "run", fake_run), contextlib.redirect_stdout(io.StringIO()):
        probe.main()
    assert len(calls) == 2
    assert "--keys" not in calls[0] and "--keys" in calls[1]
    assert all("--restore-state" in c and "--rom" not in c and "--font16" not in c
               and "--ram" not in c and "--disk-output" not in c for c in calls)
    result = json.loads((root / "good/provenance.json").read_text())
    assert result["unchanged_inputs"] and not result["gameplay_verified"]
    assert result["continuations"][-1]["absolute_duration_ms"] == 12000
    # Refuse an altered runner before creating output or starting execution.
    runner.write_bytes(b"changed")
    with mock.patch.object(sys, "argv", argv), contextlib.redirect_stderr(io.StringIO()):
        try:
            probe.main()
        except SystemExit as error:
            assert error.code == 2
        else:
            raise AssertionError("altered native runner accepted")
    runner.write_bytes(b"synthetic-not-emulated-Vtop")
    # A timeout retains partial logs and does not claim boot/playability.
    def timeout(command, **kwargs):
        raise subprocess.TimeoutExpired(command, kwargs["timeout"], b"partial", b"error")
    argv[argv.index("--output") + 1] = str(root / "timeout")
    with mock.patch.object(sys, "argv", argv), mock.patch.object(subprocess, "run", timeout):
        try:
            probe.main()
        except SystemExit:
            pass
        else:
            raise AssertionError("timeout accepted")
    result = json.loads((root / "timeout/provenance.json").read_text())
    assert result["continuations"][0]["returncode"] == 124
    assert not result["gameplay_verified"]
    assert "partial" in (root / "timeout/native8000ms.stdout").read_text()
    assert "incomplete" in (root / "timeout/native8000ms.stderr").read_text()
print("PASS: frozen native-state continuation, elapsed durations, asset integrity and timeout evidence; no emulation")
