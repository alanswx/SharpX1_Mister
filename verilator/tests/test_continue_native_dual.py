"""Asset-free collector mock: ordered B identity and no restore-time downloads.

This tests provenance plumbing only, not RTL snapshots or native gameplay.
"""
import contextlib
import io
import json
import pathlib
import subprocess
import sys
import tempfile
from unittest.mock import patch
import continue_native_probe as collector


def main():
    with tempfile.TemporaryDirectory(prefix="x1-continue-dual-mock-") as temp:
        root = pathlib.Path(temp).resolve()
        runner, state, a, b = [root/name for name in ("mock-runner", "cold.state", "a.d88", "b.d88")]
        for path in (runner,state,a,b):
            path.write_bytes(path.name.encode())
        evidence = root/"evidence.json"
        original = [str(runner),"--disk",str(a),"--disk-b",str(b),"--save-state",str(state)]
        evidence.write_text(json.dumps({"repeatable":True,"unchanged_inputs":True,
            "duration_seconds":1,"cycles_reference_hz":32000000,
            "executable_sha256":collector.sha(runner),
            "inputs_sha256":{str(p):collector.sha(p) for p in (a,b)},
            "runs":[{"command":original,"artifacts":{".state":collector.sha(state)}}]}))
        calls = []
        def mock_run(command, **kwargs):
            calls.append(command)
            assert command[command.index("--disk")+1] == str(a)
            assert command[command.index("--disk-b")+1] == str(b)
            assert not any(flag in command for flag in ("--rom","--ram","--font16","--kanji-physical"))
            pathlib.Path(command[command.index("--save-state")+1]).write_bytes(b"mock checkpoint, not Verilator state")
            report = {"disk_writes":0,"time_ps":2000000000000,"frame_hash":"mock"}
            return subprocess.CompletedProcess(command,0,json.dumps(report)+"\n","")
        output = root/"continuation"
        with patch.object(sys,"argv",["collector",str(evidence),"--output",str(output),"--chunks-ms","1000"]), \
             patch.object(collector.subprocess,"run",mock_run), contextlib.redirect_stdout(io.StringIO()):
            collector.main()
        provenance = json.loads((output/"provenance.json").read_text())
        assert len(calls)==1 and provenance["unchanged_inputs"] and not provenance["gameplay_verified"]
        # A parent which drops B must fail before opening a new output or
        # invoking the runner, even though all source hashes remain unchanged.
        parent = root/"bad-parent.json"
        parent.write_text(json.dumps({"cold_evidence":str(evidence),"unchanged_inputs":True,
            "inputs_sha256":{},"continuations":[{"returncode":0,"command":[str(runner),"--disk",str(a),"--save-state",str(state)],
                "state_sha256":collector.sha(state),"absolute_duration_ms":2000}]}))
        bad_output = root/"must-not-exist"
        with patch.object(sys,"argv",["collector",str(evidence),"--output",str(bad_output),"--chunks-ms","1000",
                                      "--from-continuation",str(parent)]), \
             patch.object(collector.subprocess,"run",mock_run), contextlib.redirect_stderr(io.StringIO()):
            try:
                collector.main()
            except SystemExit as error:
                assert error.code==2
            else:
                raise AssertionError("parent dropping drive B accepted")
        assert len(calls)==1 and not bad_output.exists()
    print("PASS mocked dual native continuation: B forwarded, no asset reload, dropped-B parent rejected before output/runner; not RTL/game acceptance")


if __name__ == "__main__":
    main()
