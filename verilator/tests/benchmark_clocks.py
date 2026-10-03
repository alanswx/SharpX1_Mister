"""Interleaved wall-time comparison, equal physical duration and video frequency."""
import argparse
import json
import pathlib
import statistics
import subprocess
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("baseline", type=pathlib.Path)
parser.add_argument("single", type=pathlib.Path)
parser.add_argument("--cycles", type=int, default=32000000)
parser.add_argument("--repeat", type=int, default=3)
args = parser.parse_args()
assert args.cycles > 64 and args.repeat > 0
samples = {"baseline": [], "single": []}
reports = {}
for repetition in range(args.repeat):
    order = ("baseline", "single") if repetition % 2 == 0 else ("single", "baseline")
    for name in order:
        command = [str(getattr(args, name).resolve()), "--cycles", str(args.cycles),
                   "--rom", "../bios/ipl_x1.hex", "--video-hz", "28636364"]
        started = time.perf_counter()
        result = subprocess.run(command, check=True, capture_output=True, text=True)
        samples[name].append(time.perf_counter() - started)
        report = json.loads(result.stdout.splitlines()[-1])
        assert report["time_ps"] == args.cycles * 31250
        if name in reports:
            assert report == reports[name], "non-repeatable benchmark machine state"
        reports[name] = report
median = {name: statistics.median(values) for name, values in samples.items()}
print(json.dumps({"reference_cycles": args.cycles, "samples_seconds": samples,
                  "median_seconds": median, "speedup": median["baseline"] / median["single"],
                  "workload": "native IPL waiting for media; equal video rate; no frame/bus capture",
                  "reports": reports}, indent=2))
