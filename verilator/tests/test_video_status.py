"""Original CPU-programmed CRTC/PPI level polling, not native firmware."""
import json
import pathlib
import subprocess
import sys
import tempfile
from z80_fixture import Program

p = Program()
def output(port, value):
    p.word(0x01, port)
    p.emit(0x3E, value, 0xED, 0x79)
p.emit(0xF3)
p.word(0x31, 0xFFFF)
output(0x1A03, 0x82)
p.word(0x01, 0x1A02)
p.emit(0xED, 0x78)  # Clear inherited reset-time DAM using a real PPI read.
output(0x1A02, 0x40)
output(0x1FD0, 1)
for register, value in enumerate((63, 40, 45, 0x12, 7, 0, 4, 6, 0, 7, 0, 0, 0, 0)):
    output(0x1800, register)
    output(0x1801, value)
p.store(0xF040, 0)
p.store(0xF041, 0x84)
p.word(0x01, 0x1A01)
p.word(0x11, 512)
p.label("poll")
p.emit(0xED, 0x78, 0xE6, 0x84)
p.word(0x32, 0xF042)
p.word(0x21, 0xF040)
p.emit(0xB6, 0x77, 0x23)  # OR accumulator, then AND accumulator.
p.word(0x3A, 0xF042)
p.emit(0xA6, 0x77, 0x1B, 0x7A, 0xB3)
p.jump(0xC2, "poll")
for i, value in enumerate(b"PPIS"):
    p.store(0xF000+i, value)
p.emit(0x76)

with tempfile.TemporaryDirectory(prefix="x1-video-status-cpu-") as directory:
    root = pathlib.Path(directory)
    rom = root / "original.bin"
    rom.write_bytes(p.finish())
    for warm in (False, True):
        dump = root / f"status-{warm}"
        command = [str(pathlib.Path(sys.argv[1]).resolve()), "--cycles", "1600000",
                   "--rom", str(rom), "--dump", str(dump)]
        if warm:
            command += ["--reset-at", "25", "--reset-for-us", "10"]
        result = subprocess.run(command, check=True, capture_output=True, text=True, timeout=600)
        report = json.loads(result.stdout.splitlines()[-1])
        ram = dump.with_suffix(".ram").read_bytes()
        assert report["halted"] and report["peek"].startswith(b"PPIS".hex()), report
        assert ram[0xF040:0xF042] == bytes((0x84, 0)), ram[0xF040:0xF043].hex()
        print(json.dumps({"warm": warm, "sys_hz": report["sys_hz"],
                          "video_hz": report["video_hz"], "or": ram[0xF040],
                          "and": ram[0xF041], "frames": report["frames"]}), flush=True)
print("PASS: real CPU sees both asserted/deasserted VSYNC and VDISP through PPI after cold/warm reset")
