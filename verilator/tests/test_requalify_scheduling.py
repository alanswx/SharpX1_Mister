"""Asset-free scheduling/timeout-report unit; no emulation or gameplay assertion."""
import contextlib
import io
import json
import os
import pathlib
import subprocess
import sys
import tempfile
from unittest import mock
import requalify_commercial

with tempfile.TemporaryDirectory(prefix="x1-requalify-schedule-") as directory:
    root = pathlib.Path(directory)
    (root / "bios").mkdir()
    (root / "bios/ipl_x1.hex").write_bytes(b"mock-ROM-not-emulated")
    work = root / "verilator"
    (work / "tests").mkdir(parents=True)
    (work / "tests/commercial_boot.keys").write_text(
        "1000 2b\n1200 f0\n1202 2b\n4000 29\n4100 f0\n4102 29\n")
    exe = root / "mock-executable"
    exe.write_bytes(b"mock-runner-not-executed")
    disk = root / "mock.d88"
    disk.write_bytes(b"mock-media-not-mounted")
    previous = pathlib.Path.cwd()
    os.chdir(work)
    try:
        calls = []
        def fake_run(command, **kwargs):
            calls.append((command, kwargs))
            if "--save-state" in command:
                pathlib.Path(command[command.index("--save-state") + 1]).write_bytes(b"mock-state")
                return subprocess.CompletedProcess(command, 0,
                    json.dumps({"disk_writes": 0, "frame_hash": "mock"}) + "\n", "")
            return subprocess.CompletedProcess(command, 0, "mock-control-result\n", "")
        argv = ["requalify", str(exe), "xevious", str(disk), "--boot-chunk-ms", "8000",
                "--timeout", "7200", "--output", str(root / "chunks")]
        with mock.patch.object(sys, "argv", argv), mock.patch.object(subprocess, "run", fake_run), contextlib.redirect_stdout(io.StringIO()):
            requalify_commercial.main()
        native = [command for command, _ in calls if "--cycles" in command]
        assert len(native) == 4
        assert sum(int(c[c.index("--cycles") + 1]) for c in native[:2]) == 16000 * 32000
        assert "--rom" in native[0] and "--keys" in native[0]
        for command in native[1:]:
            assert "--restore-state" in command and "--rom" not in command and "--keys" not in command
        assert all("--ram" not in c and "--disk-output" not in c for c, _ in calls)
        assert all(kwargs["timeout"] == 7200 for _, kwargs in calls)
        # A daemon interruption retains its successful prefix. Resume verifies
        # the same runner/assets/state/schedule and does not repeat cold boot.
        saved = root / "chunks/provenance.json"
        interrupted = json.loads(saved.read_text())
        interrupted["native_boot_chain"] = interrupted["native_boot_chain"][:1]
        interrupted["gameplay_verified"] = False
        saved.write_text(json.dumps(interrupted))
        calls.clear()
        resume_argv = argv + ["--resume"]
        with mock.patch.object(sys, "argv", resume_argv), mock.patch.object(subprocess, "run", fake_run), contextlib.redirect_stdout(io.StringIO()):
            requalify_commercial.main()
        assert len(calls) == 4 and "--restore-state" in calls[0][0]
        assert "--rom" not in calls[0][0]
        # A changed checkpoint cannot be resumed even if the asset hashes agree.
        saved.write_text(json.dumps(interrupted))
        first_state = pathlib.Path(interrupted["native_boot_chain"][0]["command"][
            interrupted["native_boot_chain"][0]["command"].index("--save-state") + 1])
        first_state.write_bytes(b"changed-state")
        with mock.patch.object(sys, "argv", resume_argv), mock.patch.object(subprocess, "run", fake_run):
            try:
                requalify_commercial.main()
            except AssertionError as error:
                assert "checkpoint changed" in str(error)
            else:
                raise AssertionError("changed checkpoint resumed")
        first_state.write_bytes(b"mock-state")
        bad_schedule = list(resume_argv)
        bad_schedule[bad_schedule.index("--boot-chunk-ms") + 1] = "16000"
        with mock.patch.object(sys, "argv", bad_schedule), mock.patch.object(subprocess, "run", fake_run):
            try:
                requalify_commercial.main()
            except AssertionError as error:
                assert "schedule/model differs" in str(error)
            else:
                raise AssertionError("different resume schedule accepted")
        # A long neutral live stage also keeps its total duration and input.
        calls.clear()
        argv = ["requalify", str(exe), "druaga", str(disk), "--boot-chunk-ms", "8000",
                "--output", str(root / "long-live")]
        with mock.patch.object(sys, "argv", argv), mock.patch.object(subprocess, "run", fake_run), contextlib.redirect_stdout(io.StringIO()):
            requalify_commercial.main()
        native = [command for command, _ in calls if "--cycles" in command]
        assert len(native) == 5
        assert sum(int(c[c.index("--cycles") + 1]) for c in native) == 30250 * 32000
        assert all(c[c.index("--joya") + 1] == '255' for c in native[-2:])
        # Default scheduling remains one uninterrupted 16-second cold run.
        calls.clear()
        argv = ["requalify", str(exe), "xevious", str(disk), "--output", str(root / "default")]
        with mock.patch.object(sys, "argv", argv), mock.patch.object(subprocess, "run", fake_run), contextlib.redirect_stdout(io.StringIO()):
            requalify_commercial.main()
        assert calls[0][0][calls[0][0].index("--cycles") + 1] == str(16000 * 32000)
        # Never silently drop scheduled key events to shorten a boot chunk.
        argv += ["--boot-chunk-ms", "4000"]
        with mock.patch.object(sys, "argv", argv), contextlib.redirect_stderr(io.StringIO()):
            try:
                requalify_commercial.main()
            except SystemExit as error:
                assert error.code == 2
            else:
                raise AssertionError("pending boot keys accepted")
        # Shanghai changes preparation, not its release-bound assertions.
        # These are mock route/schedule checks, never gameplay evidence.
        for mode in ("feedback", "historical"):
            calls.clear()
            argv = ["requalify", str(exe), "shanghai", str(disk),
                    "--shanghai-preparation", mode, "--output", str(root / mode)]
            with mock.patch.object(sys, "argv", argv), mock.patch.object(subprocess, "run", fake_run), contextlib.redirect_stdout(io.StringIO()):
                requalify_commercial.main()
            native = [c for c, _ in calls if "--cycles" in c]
            control = calls[-1][0]
            assert len(native) == (4 if mode == "feedback" else 51)
            assert control.count("--output") == 1
            assert control[1] == ("tests/prepare_shanghai_pair.py" if mode == "feedback"
                                  else "tests/test_shanghai_gameplay.py")
            evidence = json.loads((root / mode / "provenance.json").read_text())
            assert evidence["shanghai_preparation"] == mode
        def timeout(command, **kwargs):
            raise subprocess.TimeoutExpired(command, kwargs["timeout"], b"partial-native", b"partial-error")
        argv = ["requalify", str(exe), "xevious", str(disk), "--output", str(root / "timeout")]
        with mock.patch.object(sys, "argv", argv), mock.patch.object(subprocess, "run", timeout):
            try:
                requalify_commercial.main()
            except RuntimeError:
                pass
            else:
                raise AssertionError("timeout accepted")
        evidence = json.loads((root / "timeout/provenance.json").read_text())
        assert not evidence["gameplay_verified"]
        assert evidence["native_boot_chain"][0]["returncode"] == 124
        assert "partial-native" in (root / "timeout/cold16s.stdout").read_text()
        assert "partial-error" in (root / "timeout/cold16s.stderr").read_text()
        assert "command incomplete" in (root / "timeout/cold16s.stderr").read_text()
        def control_timeout(command, **kwargs):
            if "--cycles" in command:
                return fake_run(command, **kwargs)
            return timeout(command, **kwargs)
        argv = ["requalify", str(exe), "xevious", str(disk), "--output", str(root / "control-timeout")]
        with mock.patch.object(sys, "argv", argv), mock.patch.object(subprocess, "run", control_timeout), contextlib.redirect_stdout(io.StringIO()):
            try:
                requalify_commercial.main()
            except SystemExit:
                pass
            else:
                raise AssertionError("control timeout accepted")
        evidence = json.loads((root / "control-timeout/provenance.json").read_text())
        assert not evidence["gameplay_verified"] and evidence["control_returncode"] == 124
        assert "partial-native" in (root / "control-timeout/controls.stdout").read_text()
    finally:
        os.chdir(previous)
print("PASS: asset-free 16-second boot scheduling, complete key events and failed-timeout evidence; no emulation")
