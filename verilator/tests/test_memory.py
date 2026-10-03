"""Execute original Z80 diagnostics through the actual machine download port."""
import json
import pathlib
import subprocess
import sys
import tempfile
from z80_fixture import memory_diagnostic

exe = str(pathlib.Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix="x1-memory-") as folder:
    image = pathlib.Path(folder) / "diagnostic.bin"
    image.write_bytes(memory_diagnostic())
    command = [exe, "--cycles", "2000000", "--rom", str(image),
               "--ram", str(image), "--load-address", "0", "--peek", "0xf000"]
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    report = json.loads(result.stdout.splitlines()[-1])
    assert report["halted"], report
    assert report["peek"].startswith(b"X1OK".hex()), report
    assert report["download_bytes"] == 2 * image.stat().st_size
    # Also test the explicit RAM/debug bootstrap, independent of a BIOS.
    image.write_bytes(bytes((0x3E, 0x42, 0x32, 0x00, 0xF0, 0x76)))
    result = subprocess.run([exe, "--cycles", "10000", "--ram", str(image)],
                            check=True, capture_output=True, text=True)
    report = json.loads(result.stdout.splitlines()[-1])
    assert report["halted"] and report["peek"].startswith("42"), report
print("PASS: CPU instruction fetch, RAM patterns/boundaries, writes under IPL, overlay off/on, RAM bootstrap")
