"""Generated-media regression: unsupported B stays not-ready; A recovers.

Exercises the same status mask as Arcus without private program bytes or a
ready bypass. This deliberately does not claim two-drive support.
"""
import csv
import json
import pathlib
import struct
import subprocess
import sys
import tempfile
from z80_fixture import Program

p = Program(0x8000)
p.emit(0xF3)
p.word(0x31, 0xFFFF)


def select(value):
    p.word(0x01, 0x0FFC)
    p.emit(0x3E, value, 0xED, 0x79)
    p.word(0x01, 0x0FF8)


for trial in range(2):
    select(0x81)
    p.word(0x11, 100)
    p.label(f"empty{trial}")
    p.emit(0xED, 0x78)
    p.word(0x32, 0xF010 + trial)
    p.emit(0xE6, 0x80, 0xFE, 0x80)
    p.jump(0xC2, "fail")
    p.emit(0x1B, 0x7A, 0xB3)
    p.jump(0xC2, f"empty{trial}")
    select(0x80)
    p.word(0x11, 0xFFFF)
    p.label(f"ready{trial}")
    p.emit(0xED, 0x78, 0xE6, 0x80)
    p.jump(0xCA, f"selected{trial}")
    p.emit(0x1B, 0x7A, 0xB3)
    p.jump(0xC2, f"ready{trial}")
    p.jump(0xC3, "fail")
    p.label(f"selected{trial}")
for index, value in enumerate(b"DSEL"):
    p.store(0xF000 + index, value)
p.emit(0x76)
p.label("fail")
p.store(0xF000, 0xEE)
p.emit(0x76)

header = bytearray(688)
header[:8] = b"ORIGINAL"
struct.pack_into("<I", header, 28, 688 + 16 + 256)
struct.pack_into("<I", header, 32, 688)
sector = bytearray(16)
sector[2:4] = bytes((1, 1))
struct.pack_into("<H", sector, 4, 1)
struct.pack_into("<H", sector, 14, 256)
image = bytes(header + sector + bytearray(range(256)))

exe = str(pathlib.Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix="x1-drive-selection-") as directory:
    root = pathlib.Path(directory)
    ram, disk = root / "select.bin", root / "original.d88"
    ram.write_bytes(p.finish())
    disk.write_bytes(image)
    runs = []
    for repeat in range(2):
        dump, trace = root / f"run{repeat}", root / f"run{repeat}.csv"
        result = subprocess.run([exe, "--cycles", "1000000", "--ram", str(ram),
                                 "--disk", str(disk), "--dump", str(dump),
                                 "--bus-trace", str(trace), "--io-only", "--bus-events"],
                                check=True, capture_output=True, text=True, timeout=180)
        report = json.loads(result.stdout.splitlines()[-1])
        memory = dump.with_suffix(".ram").read_bytes()
        assert report["halted"] and memory[0xF000:0xF004] == b"DSEL", report
        assert all(value & 0x80 for value in memory[0xF010:0xF012]), memory[0xF010:0xF012].hex()
        assert report["disk_writes"] == 0 and disk.read_bytes() == image
        with trace.open() as stream:
            rows = [{k: int(v) for k, v in row.items()} for row in csv.DictReader(stream)]
        status = [row for row in rows if row["address"] == 0x0FF8 and not row["rd_n"]]
        b = [row for row in status if row["drive_control"] == 0x81]
        a = [row for row in status if row["drive_control"] == 0x80 and row["media_ready"]]
        assert len(b) == 200 and len(a) >= 2, (len(b), len(a))
        assert all(row["motor"] and not row["media_ready"] and row["data_in"] & 0x80 for row in b)
        assert all(row["motor"] and not row["data_in"] & 0x80 for row in a)
        runs.append((report, memory, rows))
    assert runs[0] == runs[1], "cold repeats differ"
print("PASS: generated valid A media, two B-not-ready/A-ready transitions, actual drive/motor/ready/status trace, no fake readiness and unchanged image")
