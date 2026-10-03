"""Shared-machine timing/reset smoke test; deliberately not a boot test."""
import json
import pathlib
import re
import subprocess
import sys
import tempfile

exe = str(pathlib.Path(sys.argv[1]).resolve())
root = pathlib.Path(__file__).resolve().parents[2]
manifest = root / "rtl/machine.qip"
sources = re.findall(r"^set_global_assignment -name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)$",
                     manifest.read_text(), re.MULTILINE)
assert sources and len(sources) == len(set(sources))
assert "rtl/sharpx1.v" in sources and "rtl/sharpx1_legacy.v" not in sources
assert all((root / source).is_file() for source in sources)
assert "source rtl/machine.qip" in (root / "files.qip").read_text()
assert "MACHINE_MANIFEST = ../rtl/machine.qip" in (root / "verilator/Makefile").read_text()
for wrapper in ("sharpx1.sv", "verilator/sim.v"):
    assert re.search(r"\bsharpx1\s+\w+\s*\(", (root / wrapper).read_text())
pll = (root / "rtl/pll/pll_0002.v").read_text()
assert '.output_clock_frequency0("32.000000 MHz")' in pll
assert '.output_clock_frequency1("28.571428 MHz")' in pll


def run(cycles, reset, trace=None, video_hz=None):
    args = [exe, "--cycles", str(cycles), "--reset-cycles", str(reset)]
    if video_hz is not None:
        args += ["--video-hz", str(video_hz)]
    else:
        video_hz = 28571428
    if trace:
        args += ["--trace", str(trace)]
    result = subprocess.run(args, check=True, capture_output=True, text=True)
    # Inherited machine diagnostics may precede the result.
    report = json.loads(result.stdout.splitlines()[-1])
    assert report["machine"] == "sharpx1"
    assert report["sys_hz"] == 32000000
    assert report["sys_edges"] == cycles
    assert report["time_ps"] == cycles * 31250
    assert report["reset_edges"] == reset
    assert report["delayed_sys_edges"] == cycles
    # Number of half-period video edges in the interval, rounded to ps.
    assert report["video_hz"] == video_hz
    half_edges = (report["time_ps"] * 2 * video_hz) // 10**12
    assert report["video_edges"] == (half_edges + 1) // 2
    # Divider resets to zero; release coincides with the first increment.
    expected_enables = sum(i % 8 == 4 for i in range(1, cycles - reset + 1))
    assert report["cpu_enables"] == expected_enables, report
    return report


for cycles, reset in [(256, 64), (4096, 17), (200000, 64)]:
    assert run(cycles, reset) == run(cycles, reset), "nondeterministic run"
assert run(4096, 17, video_hz=28636360) == run(4096, 17, video_hz=28636360)
with tempfile.TemporaryDirectory(prefix="x1-timing-") as directory:
    trace = pathlib.Path(directory) / "timing.fst"
    assert run(256, 64, trace) == run(256, 64)
    assert trace.stat().st_size > 0
for args in [("--cycles", "0"), ("--cycles", "-1"), ("--reset-cycles", "0"),
             ("--unknown",), ("--cycles", "invalid"), ("--video-hz", "0"),
             ("--cycles", "1000000000001")]:
    assert subprocess.run([exe, *args], capture_output=True).returncode == 2
print("PASS: shared sources, board clock contract, clocks, reset, CPU enables, delayed events, determinism, FST, CLI")
