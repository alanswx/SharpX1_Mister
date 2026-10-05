"""Bounded/event bus traces retain last sampled data without changing execution."""
import csv
import json
import math
import pathlib
import subprocess
import sys
import tempfile
from z80_fixture import Program

p = Program()
p.emit(0xF3)
p.word(0x01, 0x1C00)
p.emit(0xAF, 0xED, 0x79)
p.word(0x01, 0x1B00)
p.label("loop")
p.emit(0xED, 0x78)
p.word(0x32, 0xF000)
p.emit(0x3E, 0x3C, 0xED, 0x79)
p.jump(0xC3, "loop")

exe = str(pathlib.Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix="x1-bus-trace-") as directory:
    root = pathlib.Path(directory)
    rom = root / "io.bin"
    rom.write_bytes(p.finish())
    reports, traces = {}, {}
    base = [exe, "--cycles", "96000", "--rom", str(rom)]
    for name, extra in (("none", []), ("raw", []), ("events", ["--bus-events"]),
                        ("window", ["--bus-events", "--bus-start-ms", "1", "--bus-end-ms", "2"])):
        path = root / f"{name}.csv"
        args = base + ([] if name == "none" else ["--bus-trace", str(path), "--io-only", *extra])
        result = subprocess.run(args, check=True, capture_output=True, text=True)
        reports[name] = json.loads(result.stdout.splitlines()[-1])
        if name != "none":
            with path.open() as stream:
                traces[name] = [{k: int(v) for k, v in row.items()} for row in csv.DictReader(stream)]
    assert all(report == reports["none"] for report in reports.values()), reports
    period = math.ceil(10**12 / reports["none"]["sys_hz"])

    def deduplicate(rows):
        result, last = [], None
        for row in rows:
            key = tuple(row[name] for name in ("address", "mreq_n", "iorq_n", "rd_n", "wr_n"))
            if last is None or key != last[0] or row["time_ps"] - last[1] > period + 1:
                result.append(row)
            else:
                result[-1] = row
            last = key, row["time_ps"]
        return result

    assert traces["events"] == deduplicate(traces["raw"])
    expected_window = deduplicate([r for r in traces["raw"] if 10**9 <= r["time_ps"] < 2*10**9])
    assert traces["window"] == expected_window
    assert 0 < len(traces["window"]) < len(traces["events"]) < len(traces["raw"])
    for args in (("--bus-events",), ("--bus-start-ms", "1"),
                 ("--bus-trace", str(root/"invalid.csv"), "--bus-start-ms", "2", "--bus-end-ms", "1"),
                 ("--bus-trace", str(root/"invalid.csv"), "--bus-end-ms", "1000000001")):
        result = subprocess.run(base + list(args), capture_output=True, text=True)
        assert result.returncode != 0, args
    print(json.dumps({"raw_rows": len(traces["raw"]), "events": len(traces["events"]),
                      "window_events": len(traces["window"])}))
print("PASS: raw/event last-sample identity, half-open trace window, unchanged execution and invalid-option rejection")
