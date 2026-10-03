"""Original CPU fixture for base-X1 beam-addressed PCG and ANK readback."""
import json
import csv
import pathlib
import subprocess
import sys
import tempfile
from z80_fixture import Program

p = Program()
p.emit(0xF3)


def output(port, value):
    p.word(0x01, port)
    p.emit(0x3E, value, 0xED, 0x79)


def equal(port, value):
    p.word(0x01, port)
    p.emit(0xED, 0x78, 0xFE, value)
    p.jump(0xC2, "fail")


output(0x1A03, 0x82)
equal(0x1A02, 0)  # Clear reset-time DAM.
output(0x1A02, 0x40)
# Fill all mirrored text cells with 'A', making the beam's glyph stable.
p.word(0x01, 0x3000)
p.word(0x11, 2048)
p.emit(0x3E, 65)
p.label("fill")
p.emit(0xED, 0x79, 0x03, 0x1B, 0x7A, 0xB3)
p.jump(0xCA, "filled")
p.emit(0x3E, 65)
p.jump(0xC3, "fill")
p.label("filled")
# Explicitly clear attributes; do not depend on power-up VRAM contents.
p.word(0x01, 0x2000)
p.word(0x11, 2048)
p.label("attributes")
p.emit(0xAF, 0xED, 0x79, 0x03, 0x1B, 0x7A, 0xB3)
p.jump(0xC2, "attributes")
# A single-raster-row character, so the beam always accesses glyph row zero.
for register, value in enumerate((15, 1, 2, 0x12, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0)):
    output(0x1800, register)
    output(0x1801, value)
# Allow several scanlines to latch the programmed text and row.
p.word(0x11, 512)
p.label("delay")
p.emit(0x1B, 0x7A, 0xB3)
p.jump(0xC2, "delay")
for port, value in ((0x1500, 0xA5), (0x1600, 0x3C), (0x1700, 0x81)):
    output(port, value)
for port, value in ((0x15FF, 0xA5), (0x16AB, 0x3C), (0x1755, 0x81)):
    equal(port, value)  # Low I/O address does not select the glyph/row.
equal(0x1400, 0x18)  # Existing ANK font 'A', row 0.
output(0x14FF, 0)
equal(0x14AB, 0x18)  # Writes to ANK are ignored.
for i, value in enumerate(b"PCG!"):
    p.store(0xF000 + i, value)
p.emit(0x76)
p.label("fail")
p.store(0xF000, 0xEE)
p.emit(0x76)

exe = str(pathlib.Path(sys.argv[1]).resolve())
if len(sys.argv) == 2:
    for video_hz in (28571428, 4000000):
        subprocess.run([sys.executable, __file__, exe, str(video_hz)], check=True)
    sys.exit(0)
video_hz = int(sys.argv[2])
with tempfile.TemporaryDirectory(prefix="x1-pcg-") as directory:
    rom = pathlib.Path(directory) / "pcg.bin"
    trace = pathlib.Path(directory) / "bus.csv"
    rom.write_bytes(p.finish())
    result = subprocess.run([exe, "--cycles", "2000000", "--video-hz", str(video_hz), "--rom", str(rom),
                             "--bus-trace", str(trace), "--io-only"],
                            check=True, capture_output=True, text=True)
    report = json.loads(result.stdout.splitlines()[-1])
    assert report["halted"] and report["peek"].startswith(b"PCG!".hex()), report
    # Deliberately slow the video domain to force real Z80 wait states. At the
    # board clock the transaction may fit inside TV80's mandatory I/O wait.
    runs, current, previous_time = [], None, 0
    with trace.open() as stream:
        for row in csv.DictReader(stream):
            now = int(row["time_ps"])
            key = (int(row["address"]), int(row["rd_n"]), int(row["wr_n"]))
            if current is None or key != current[0] or abs(now - previous_time - 10**12/report["sys_hz"]) > 1:
                current = [key, 0]
                runs.append(current)
            current[1] += 1
            previous_time = now
    ordinary = [count for (port, rd, wr), count in runs if port == 0x1A02 and rd == 0]
    pcg_reads = [count for (port, rd, wr), count in runs if 0x1400 <= port <= 0x17FF and rd == 0]
    # Fractional enables can vary the ordinary bus duration by one master tick.
    tolerance = 0 if report["sys_hz"] == 32000000 else 1
    assert ordinary and pcg_reads and min(pcg_reads) + tolerance >= max(ordinary), (ordinary, pcg_reads)
    if video_hz == 4000000:
        assert min(pcg_reads) > max(ordinary), (ordinary, pcg_reads)
    print(json.dumps({"video_hz": report["video_hz"], "ordinary_read_sys_edges": ordinary,
                      "pcg_read_sys_edges": pcg_reads}))
print("PASS: Z80 beam-addressed PCG readback/mirrors, read-only ANK and extended I/O WAIT strobes")
