"""Single-clock scheduler contract, rate accuracy, determinism and traces."""
import json
import pathlib
import subprocess
import sys
import tempfile

exe = str(pathlib.Path(sys.argv[1]).resolve())

def run(cycles, reset=64, extra=()):
    result = subprocess.run([exe, "--cycles", str(cycles), "--reset-cycles", str(reset), *extra],
                            check=True, capture_output=True, text=True)
    report = json.loads(result.stdout.splitlines()[-1])
    assert report["sys_hz"] == report["video_hz"] == 28636364
    assert report["time_ps"] == cycles * 31250
    assert report["sys_edges"] == report["video_edges"]
    assert abs(report["sys_edges"] - cycles * 28636364 / 32000000) <= 1
    assert abs(report["cpu_enables"] - (cycles - reset) / 8) <= 2
    assert 0 <= report["sys_edges"] - report["delayed_sys_edges"] <= 1
    return report

for cycles, reset in ((256, 64), (4096, 17), (200000, 64)):
    assert run(cycles, reset) == run(cycles, reset)
with tempfile.TemporaryDirectory(prefix="x1-single-clock-") as folder:
    trace = pathlib.Path(folder) / "clock.fst"
    assert run(4096, extra=("--trace", str(trace))) == run(4096)
    assert trace.stat().st_size > 0
assert subprocess.run([exe, "--video-hz", "28571428"], capture_output=True).returncode == 2
print("PASS: single clock, physical duration, fractional CPU rate, repeatable reset, FST, incompatible-clock rejection")
