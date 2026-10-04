"""Optional private-asset test: warm reboot a running native game, no reload."""
import json
import pathlib
import subprocess
import sys

exe, state, disk = (pathlib.Path(value).resolve() for value in sys.argv[1:4])
warm = state.with_name("cross-warm-reset.state")
result = subprocess.run([str(exe), "--cycles", "416000000", "--restore-state", str(state),
                         "--disk", str(disk), "--reset-at", "1", "--reset-for-us", "1000",
                         "--keys", "tests/cross_start.keys", "--save-state", str(warm),
                         "--frame", str(warm.with_suffix(".ppm")), "--progress"],
                        check=True, capture_output=True, text=True, timeout=600)
report = json.loads(result.stdout.splitlines()[-1])
assert report["download_bytes"] == 0, "reset must reuse the already downloaded IPL"
assert report["disk_requests"] > 0 and report["disk_writes"] == 0, report
assert report["frame_width"] == 320 and report["frame_height"] == 200, report
subprocess.run([sys.executable, "tests/test_gameplay.py", str(exe), str(warm), str(disk)], check=True)
print(json.dumps({"warm_reset_ms": 1, "reset_width_us": 1000,
                  "reboot_duration_ms": 13000, "disk_reads": report["disk_requests"],
                  "download_bytes": report["download_bytes"], "snapshot": str(warm)}))
print("PASS: native game warm-reboots through retained IPL/mounted disk and remains keyboard-playable without core reload")
