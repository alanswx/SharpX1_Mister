"""Original ROM: re-enter IPL after repeated warm resets without reloading it."""
import json
import pathlib
import subprocess
import sys
import tempfile

exe = str(pathlib.Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix="x1-warm-reset-") as temporary:
    folder = pathlib.Path(temporary)
    rom, ram = folder / "ipl.bin", folder / "program.bin"
    # IPL increments persistent RAM F000 and jumps to high RAM. The program
    # disables IPL, leaves a marker, and HALTs. A warm reset must recover from
    # both HALT and the disabled overlay, retaining the original downloaded ROM.
    rom.write_bytes(bytes.fromhex("f3 21 00 f0 34 c3 00 80"))
    ram.write_bytes(bytes.fromhex("f3 01 00 1e ed 79 3e 42 32 01 f0 76"))
    command = [exe, "--cycles", "160000", "--rom", str(rom), "--ram", str(ram),
               "--peek", "0xf000", "--bus-trace", str(folder / "bus.csv")]
    def run(options):
        result = subprocess.run(command + options, capture_output=True, text=True, timeout=30)
        assert result.returncode == 0, result.stderr
        return json.loads(result.stdout.splitlines()[-1])
    cold = run([])
    assert cold["halted"] and cold["peek"].startswith("0142"), cold
    for width in (1, 100, 1000):
        options = ["--reset-at", "1", "--reset-at", "3", "--reset-for-us", str(width)]
        warm = run(options)
        assert warm["halted"] and warm["peek"].startswith("0342"), (width, warm)
        assert warm["download_bytes"] == cold["download_bytes"]
        assert warm["reset_edges"] > cold["reset_edges"]
        assert run(options) == warm, "warm reset is not deterministic"
    for options in (["--reset-at", "0"], ["--reset-at", "5"],
                    ["--reset-at", "2", "--reset-at", "1"], ["--reset-for-us", "0"]):
        assert subprocess.run(command + options, capture_output=True).returncode != 0
    bad = subprocess.run(command + ["--reset-at", "1", "--reset-at", "2",
                                    "--reset-for-us", "1000"], capture_output=True, text=True)
    assert bad.returncode != 0 and "non-overlapping" in bad.stderr
print("PASS: repeated warm reset recovers HALT/IPL overlay, retains ROM/RAM, repeatable pulses and invalid schedule rejection")
